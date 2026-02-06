public struct TopicFilter: Hashable, Sendable {
    public let topic: String
    public let qos: QoS
    public init(topic: String, qos: QoS) {
        self.topic = topic
        self.qos = qos
    }
}

public struct SubscribeVariableHeader: Equatable, Sendable {
    public var packetId: UInt16

    public init(packetId: UInt16) {
        self.packetId = packetId
    }

    public func encode() -> Bytes {
        return encodeUInt16(self.packetId)
    }

    public func toString() -> String {
        return "packetId: \(self.packetId)"
    }
}

public struct SubscribePayload: Equatable, Sendable {
    public let topics: [TopicFilter]

    public init(topics: [TopicFilter]) {
        self.topics = topics
    }

    public func encode() -> Bytes {
        var data: Bytes = []

        for topicFilter in self.topics {
            data.append(contentsOf: encodeUInt16(UInt16(topicFilter.topic.utf8.count)))
            data.append(contentsOf: topicFilter.topic.utf8)
            data.append(topicFilter.qos.rawValue)
        }

        return data
    }

    public func toString() -> String {
        let s = self.topics.map { "topic: \($0.topic), QoS: \($0.qos)"}.joined(separator: ", ")
        return s
    }
}

public struct Subscribe: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: SubscribeVariableHeader
    public var payload: SubscribePayload

    public init(packetId: UInt16 = 1, topics: [TopicFilter]) {
        self.varHeader = SubscribeVariableHeader(packetId: packetId)
        self.payload = SubscribePayload(topics: topics)
        self.fixedHeader = FixedHeader(type: .SUBSCRIBE, flags: 0b0010, remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }

    public func encode() -> Bytes {
        var data: Bytes = []
        data.append(contentsOf: fixedHeader.encode())
        data.append(contentsOf: varHeader.encode())
        data.append(contentsOf: payload.encode())

        return data
    }

    public func toString() -> String {
        return "SUBSCRIBE [\(self.varHeader.toString())] [\(self.payload.toString())]"
    }
}
