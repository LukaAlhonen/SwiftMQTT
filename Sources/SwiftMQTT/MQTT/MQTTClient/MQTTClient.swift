actor MQTTClient {
    private let config: Config
    private let clientId: String

    private let internalEventBus: MQTTEventBus<MQTTInternalEvent>
    private let eventBus: MQTTEventBus<MQTTEvent>
    private let internalCommandBus: MQTTEventBus<MQTTInternalCommand>

    private let internalEventStream: AsyncStream<MQTTInternalEvent>
    private let internalCommandStream: AsyncStream<MQTTInternalCommand>
    let eventStream: AsyncStream<MQTTEvent>


    private let session: MQTTSession
    private let connection: MQTTConnection
    private let idAllocator: PacketIdAllocator

    private var keepAliveTask: Task<Void, Never>?

    init(clientId: String, host: String, port: Int, config: Config) {
        self.clientId = clientId
        self.config = config

        var internalCont: AsyncStream<MQTTInternalEvent>.Continuation!
        var internalCommandCont: AsyncStream<MQTTInternalCommand>.Continuation!
        var cont: AsyncStream<MQTTEvent>.Continuation!

        // TODO: Should probably let user define how many events to buffer
        self.internalEventStream = AsyncStream(bufferingPolicy: .bufferingNewest(10)) { internalCont = $0 }
        self.eventStream = AsyncStream(bufferingPolicy: .bufferingNewest(10)) { cont = $0 }

        self.internalEventBus = MQTTEventBus<MQTTInternalEvent>(continuation: internalCont)
        self.eventBus = MQTTEventBus<MQTTEvent>(continuation: cont)

        self.internalCommandStream = AsyncStream(bufferingPolicy: .bufferingNewest(10)) { internalCommandCont = $0 }
        self.internalCommandBus = MQTTEventBus<MQTTInternalCommand>(continuation: internalCommandCont )

        self.session = MQTTSession(config: config, eventBus: eventBus, commandBus: internalCommandBus)
        self.connection = MQTTConnection(host: host, port: port, eventBus: internalEventBus)

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
                        // should handle error here
                        try? await self.send(packet)
                    case .disconnect(let error):
                        await self.disconnect(with: error)
                }
            }
        }
    }
}

extension MQTTClient {
    func connect() async throws {
        // try await self.tryConnect()
        try await self.connectLoop()
        self.startKeepAlive()
    }

    private func tryConnect() async throws {
        try await self.connection.connect()
        try await self.send(Connect(clientId: self.clientId, keepAlive: 60))
        try await self.session.awaitConack()
    }

    private func connectLoop() async throws {
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
    func publish(bytes: Bytes, qos: QoS, topic: String) async throws {
        let packetId = await idAllocator.next()
        let publish = Publish(topicName: topic, message: bytes, packetId: packetId, qos: qos)

        try await sendPublish(publish)

        switch qos {
            case .ExactlyOnce:
                try await self.session.awaitPubrec(packetId: packetId)
                try await self.send(Pubrec(packetId: packetId))
                try await self.session.awaitPubComp(packetId: packetId)
            case .AtLeastOnce:
                try await session.awaitPuback(packetId: packetId)
            case .AtMostOnce:
                break
        }
    }

    func publish(message: String, qos: QoS, topic: String) async throws {
        let packetId = await idAllocator.next()
        let publish = Publish(topicName: topic, message: message, packetId: packetId, qos: qos)

        try await sendPublish(publish)
    }

    private func sendPublish(_ publish: Publish) async throws {
        try await self.send(publish)
    }
}

// MARK: Subscribe
extension MQTTClient {
    func subscribe(to topics: [TopicFilter]) async throws {
            let packetId = await self.idAllocator.next()
            let subscribePacket = Subscribe(packetId: packetId, topics: topics)

            try await self.send(subscribePacket)
            try await self.session.awaitSuback(packetId: packetId)
    }

    private func subscribeToTopics() async throws {
        let topics = await self.session.getSubscriptions()
        if topics.count <= 0 { return }

        try await self.subscribe(to: topics)
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

extension MQTTClient {
    func stop() {

    }

    private func disconnect(with error: (any Error)?) async {
        try? await self.connection.close()
        if let error = error {
            self.eventBus.emit(.error(error))
        }
        self.eventBus.finnish()
    }
}
