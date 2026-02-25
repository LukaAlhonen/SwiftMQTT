public final class MQTTClientV3: Sendable {
    private let client: MQTTClient
    public let eventStream: AsyncStream<MQTTEvent>

    public init(clientId: String, host: String, port: Int, config: Config) {
        var cont: AsyncStream<MQTTEvent>.Continuation!
        self.eventStream = AsyncStream(bufferingPolicy: .bufferingNewest(10)) { cont = $0 }
        let eventBus = MQTTEventBus<MQTTEvent>(continuation: cont)

        self.client = .init(version: .v3, clientId: clientId, host: host, port: port, config: config, eventBus: eventBus)
    }
}

// MARK: Connect
public extension MQTTClientV3 {
    func connect() async throws {
        try await self.client.connect()
    }
}

// MARK: Subscribe
public extension MQTTClientV3 {
    @discardableResult func subscribe(to topics: [TopicFilter]) async throws -> Subscribe {
        try await self.client.subscribe(to: topics)
    }
}

// MARK: Unsubscribe
public extension MQTTClientV3 {
    @discardableResult func unsubscribe(from topics: [String]) async throws -> Unsubscribe {
        return try await self.client.unsubscribe(from: topics)
    }
}

// MARK: Publish
public extension MQTTClientV3 {
    @discardableResult func publish(bytes: Bytes, qos: QoS, topic: String) async throws -> Publish{
        return try await self.client.publish(bytes: bytes, qos: qos, topic: topic)
    }

    @discardableResult func publish(message: String, qos: QoS, topic: String) async throws -> Publish {
        return try await self.client.publish(message: message, qos: qos, topic: topic)
    }
}

// MARK: Disconnect
public extension MQTTClientV3 {
    func stop() async {
        await self.client.stop()
    }
}
