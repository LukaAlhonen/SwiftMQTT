actor MQTTClient {
    private let config: Config
    private let clientId: String

    private let internalEventBus: MQTTEventBus<MQTTInternalEvent>
    private let eventBus: MQTTEventBus<MQTTEvent>
    private let internalCommandBus: MQTTEventBus<MQTTInternalCommand>

    private let internalEventStream: AsyncStream<MQTTInternalEvent>
    private let internalCommandStream: AsyncStream<MQTTInternalCommand>

    private let session: MQTTSession
    private let connection: MQTTConnection
    private let idAllocator: PacketIdAllocator

    private var keepAliveTask: Task<Void, Never>?

    private let version: Version
    private let connectProperties: ConnectProperties?
    private let willProperties: WillProperties?

    init(
        version: Version, connectProperties: ConnectProperties? = nil,
        willProperties: WillProperties? = nil, clientId: String, host: String,
        port: Int,
        config: Config,
        eventBus: MQTTEventBus<MQTTEvent>
    ) {
        self.version = version
        self.connectProperties = connectProperties
        self.willProperties = willProperties
        self.clientId = clientId
        self.config = config

        var internalCont: AsyncStream<MQTTInternalEvent>.Continuation!
        var internalCommandCont: AsyncStream<MQTTInternalCommand>.Continuation!

        // TODO: Should probably let user define how many events to buffer
        self.internalEventStream = AsyncStream(bufferingPolicy: .bufferingNewest(10)) {
            internalCont = $0
        }

        self.internalEventBus = MQTTEventBus<MQTTInternalEvent>(continuation: internalCont)
        self.eventBus = eventBus

        self.internalCommandStream = AsyncStream(bufferingPolicy: .bufferingNewest(10)) {
            internalCommandCont = $0
        }
        self.internalCommandBus = MQTTEventBus<MQTTInternalCommand>(
            continuation: internalCommandCont)

        self.session = MQTTSession(
            config: config, eventBus: eventBus, commandBus: internalCommandBus)
        self.connection = MQTTConnection(
            host: host, port: port, eventBus: internalEventBus, version: self.version)

        self.idAllocator = .init()

        // Read events from connection
        Task {
            for await event in self.internalEventStream {
                await self.session.handle(event)
            }
        }

        // Read commands from session
        Task {
            for await command in self.internalCommandStream {
                switch command {
                case .send(let packet):
                    do {
                        try await self.send(packet)
                    } catch {
                        self.eventBus.emit(.error(error))
                    }
                case .disconnect(let error, let reasonCode):
                    await self.disconnect(with: error, reasonCode: reasonCode)
                }
            }
        }
    }
}

// MARK: Connect
extension MQTTClient {
    func connect() async throws {
        try await self.connectLoop()
        self.startKeepAlive()
    }

    private func tryConnect()
        async throws
    {
        try await self.connection.connect()
        try await self.send(
            Connect(
                version: self.version, clientId: self.clientId, keepAlive: 60,
                properties: self.connectProperties, willProperties: self.willProperties))
        try await self.session.awaitConack()
    }

    private func connectLoop()
        async throws
    {
        var attempts = 0

        while attempts <= self.config.maxRetries {
            do {
                try await self.tryConnect()
                return
            } catch {
                attempts = attempts + 1
            }
        }

        throw MQTTError.connectionError(.disconnected)
    }

    private func reconnect() async throws {
        try await self.connectLoop()
        // resub
        try await self.subscribeToTopics()
    }
}

// MARK: Send
extension MQTTClient {
    private func send(_ packet: any MQTTControlPacket) async throws {
        await session.handle(.send(packet))
        try await self.connection.send(packet: packet)
    }
}

// MARK: Publish
extension MQTTClient {
    @discardableResult func publish(
        bytes: Bytes, qos: QoS, topic: String, duplicate: Bool = false, retain: Bool = false,
        properties: PublishProperties? = nil
    ) async throws -> Publish {
        let publish =
            switch qos {
            case .ExactlyOnce:
                try await constructQoS2Publish(
                    bytes: bytes, topic: topic, duplicate: duplicate, retain: retain,
                    properties: properties)
            case .AtLeastOnce:
                try await constructQoS1Publish(
                    bytes: bytes, topic: topic, duplicate: duplicate, retain: retain,
                    properties: properties)
            case .AtMostOnce:
                try constructQoS0Publish(
                    bytes: bytes, topic: topic, duplicate: duplicate, retain: retain,
                    properties: properties)
            }

        try await self.sendPublish(publish, qos: qos)

        return publish
    }

    @discardableResult func publish(
        message: String, qos: QoS, topic: String, duplicate: Bool = false, retain: Bool = false,
        properties: PublishProperties? = nil
    ) async throws
        -> Publish
    {
        let publish =
            switch qos {
            case .ExactlyOnce:
                try await constructQoS2Publish(
                    bytes: Bytes(message.utf8), topic: topic, duplicate: duplicate, retain: retain,
                    properties: properties)
            case .AtLeastOnce:
                try await constructQoS1Publish(
                    bytes: Bytes(message.utf8), topic: topic, duplicate: duplicate, retain: retain,
                    properties: properties)
            case .AtMostOnce:
                try constructQoS0Publish(
                    bytes: Bytes(message.utf8), topic: topic, duplicate: duplicate, retain: retain,
                    properties: properties)
            }

        try await self.sendPublish(publish, qos: qos)

        return publish
    }

    private func sendPublish(
        _ publish: Publish, qos: QoS
    ) async throws {
        try await self.send(publish)
        switch qos {
        case .ExactlyOnce:
            guard let packetId = publish.variableHeader.packetId else {
                throw MQTTError.protocolViolation(.malformedPacket(reason: .missingPacketId))
            }
            // TODO: catch missing packateId error and throw otherwise
            // - need to send back pubrel with error code and then throw error
            try await self.session.awaitPubrec(packetId: packetId)
            try await self.send(Pubrel(packetId: packetId))
            try await self.session.awaitPubComp(packetId: packetId)
        case .AtLeastOnce:
            guard let packetId = publish.variableHeader.packetId else {
                throw MQTTError.protocolViolation(.malformedPacket(reason: .missingPacketId))
            }
            try await session.awaitPuback(packetId: packetId)
        case .AtMostOnce:
            break
        }
    }

    private func constructQoS2Publish(
        bytes: Bytes, topic: String, duplicate: Bool = false, retain: Bool = false,
        properties: PublishProperties? = nil
    ) async throws -> Publish {
        let packetId = await self.idAllocator.next()
        let publish = try Publish(
            topicName: topic, message: bytes, packetId: packetId, duplicate: duplicate,
            qos: .ExactlyOnce,
            retain: retain, properties: properties
        )

        return publish
    }

    private func constructQoS1Publish(
        bytes: Bytes, topic: String, duplicate: Bool = false, retain: Bool = false,
        properties: PublishProperties? = nil
    ) async throws -> Publish {
        let packetId = await self.idAllocator.next()
        let publish = try Publish(
            topicName: topic, message: bytes, packetId: packetId, duplicate: duplicate,
            qos: .AtLeastOnce,
            retain: retain, properties: properties
        )

        return publish
    }

    private func constructQoS0Publish(
        bytes: Bytes, topic: String, duplicate: Bool = false, retain: Bool = false,
        properties: PublishProperties? = nil
    ) throws -> Publish {
        let publish = try Publish(
            topicName: topic, message: bytes, duplicate: duplicate,
            qos: .AtMostOnce,
            retain: retain, properties: properties
        )

        return publish
    }
}

// MARK: Subscribe
extension MQTTClient {
    @discardableResult func subscribe(
        to topics: [TopicFilter], properties: SubscribeProperties? = nil
    ) async throws -> Subscribe {
        let packetId = await self.idAllocator.next()
        let subscribePacket = Subscribe(packetId: packetId, properties: properties, topics: topics)

        try await self.send(subscribePacket)
        try await self.session.awaitSuback(packetId: packetId)
        return subscribePacket
    }

    private func subscribeToTopics() async throws {
        let subs = await self.session.getSubscriptions()
        if subs.count <= 0 { return }
        for (properties, topicFilters) in subs {
            try await self.subscribe(to: topicFilters, properties: properties)
        }
    }
}

// MARK: Unsub
extension MQTTClient {
    @discardableResult func unsubscribe(
        from topics: [String], properties: UnsubscribeProperties? = nil
    ) async throws -> Unsubscribe {
        let packetId = await self.idAllocator.next()
        let unsubpacket = Unsubscribe(packetId: packetId, properties: properties, topics: topics)

        try await self.send(unsubpacket)
        try await self.session.awaitUnsuback(packetId: packetId)

        return unsubpacket
    }
}

// MARK: Keepalive
extension MQTTClient {
    private func startKeepAlive() {
        let task = Task {
            while !Task.isCancelled {
                await session.awaitKeepAlive()

                do {
                    try await self.send(Pingreq())
                    try await session.awaitPingresp()
                } catch {
                    self.eventBus.emit(.error(error))
                    do {
                        try await self.reconnect()
                    } catch {
                        await self.disconnect(with: error)
                    }
                }
            }
        }

        self.keepAliveTask = task
    }
}

// MARK: Disconnect
extension MQTTClient {
    func stop() async {
        await self.disconnect()
    }

    private func disconnect(with error: (any Error)? = nil, reasonCode: DisconnectReasonCode? = nil)
        async
    {
        try? await self.send(Disconnect(reasonCode: reasonCode))
        try? await self.connection.close()
        if let error = error {
            self.eventBus.emit(.error(error))
        }
        self.eventBus.finnish()
    }
}
