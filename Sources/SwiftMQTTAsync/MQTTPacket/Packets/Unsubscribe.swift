public struct UnsubscribePayload: Equatable, Sendable {
    public let topics: [String]

    public init(topics: [String]) {
        self.topics = topics
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []

        for topic in self.topics {
            let topicBytes = Bytes(topic.utf8)
            let topicLen = encodeUInt16(UInt16(topicBytes.count))

            bytes.append(contentsOf: topicLen)
            bytes.append(contentsOf: topicBytes)
        }

        return bytes
    }

    public func toString() -> String {
        let topicsString = self.topics.joined(separator: ", ")
        return "Topics: [\(topicsString)]"
    }
}

public struct UnsubscribeVariableHeader: Equatable, Sendable {
    public let packetId: UInt16

    public init(packetId: UInt16) {
        self.packetId = packetId
    }

    public func encode() -> Bytes {
        return encodeUInt16(self.packetId)
    }

    public func toString() -> String {
        return "Packet ID: \(self.packetId)"
    }
}

public struct Unsubscribe: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: UnsubscribeVariableHeader
    public var payload: UnsubscribePayload

    public init(packetId: UInt16, topics: [String]) {
        self.varHeader = .init(packetId: packetId)
        self.payload = .init(topics: topics)
        self.fixedHeader = .init(
            type: .UNSUBSCRIBE, flags: 2,
            remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []
        bytes.append(contentsOf: self.fixedHeader.encode())
        bytes.append(contentsOf: self.varHeader.encode())
        bytes.append(contentsOf: self.payload.encode())

        return bytes
    }

    public func toString() -> String {
        return
            "\(self.fixedHeader.toString()), \(self.varHeader.toString()), \(self.payload.toString())"
    }
}
