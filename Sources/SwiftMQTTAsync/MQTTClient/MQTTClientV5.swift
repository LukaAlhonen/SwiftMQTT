public final class MQTTClientV5: Sendable {
    private let client: MQTTClient
    public let eventStream: AsyncStream<MQTTEvent>

    public init(
        clientId: String, host: String, port: Int, config: Config,
        connectProperties: ConnectProperties = ConnectProperties(),
        willProperties: WillProperties? = nil
    ) {
        var cont: AsyncStream<MQTTEvent>.Continuation!
        self.eventStream = AsyncStream(bufferingPolicy: .bufferingNewest(10)) { cont = $0 }
        let eventBus = MQTTEventBus<MQTTEvent>(continuation: cont)

        self.client = .init(
            version: .v5, connectProperties: connectProperties, willProperties: willProperties,
            clientId: clientId, host: host, port: port, config: config,
            eventBus: eventBus)
    }
}

// MARK: Connect
extension MQTTClientV5 {
    public func connect() async throws {
        try await self.client.connect()
    }
}

// MARK: Subscribe
extension MQTTClientV5 {
    @discardableResult public func subscribe(
        to topics: [TopicFilter],
        properties: SubscribeProperties = SubscribeProperties()
    ) async throws -> Subscribe {
        try await self.client.subscribe(to: topics, properties: properties)
    }
}

// MARK: Unsubscribe
extension MQTTClientV5 {
    @discardableResult public func unsubscribe(
        from topics: [String], properties: UnsubscribeProperties = UnsubscribeProperties()
    ) async throws -> Unsubscribe {
        return try await self.client.unsubscribe(from: topics, properties: properties)
    }
}

// MARK: Publish
extension MQTTClientV5 {
    @discardableResult public func publish(
        bytes: Bytes, qos: QoS, topic: String, duplicate: Bool = false, retain: Bool = false,
        properties: PublishProperties = PublishProperties()
    ) async throws
        -> Publish
    {
        return try await self.client.publish(
            bytes: bytes, qos: qos, topic: topic, duplicate: duplicate, retain: retain,
            properties: properties)
    }

    @discardableResult public func publish(
        message: String, qos: QoS, topic: String, duplicate: Bool = false, retain: Bool = false,
        properties: PublishProperties? = PublishProperties()
    ) async throws
        -> Publish
    {
        return try await self.client.publish(
            message: message, qos: qos, topic: topic, duplicate: duplicate, retain: retain,
            properties: properties)
    }
}

// MARK: Disconnect
extension MQTTClientV5 {
    public func stop() async {
        await self.client.stop()
    }
}
