struct UnsubscribePayload: Equatable {
    let topics: [String]

    init(topics: [String]) {
        self.topics = topics
    }

    func encode() -> Bytes {
        var bytes: Bytes = []

        for topic in self.topics {
            let topicBytes = Bytes(topic.utf8)
            let topicLen = encodeUInt16(UInt16(topicBytes.count))

            bytes.append(contentsOf: topicLen)
            bytes.append(contentsOf: topicBytes)
        }

        return bytes
    }

    func toString() -> String {
        let topicsString = self.topics.joined(separator: ", ")
        return "Topics: \(topicsString)"
    }
}

struct UnsubscribeVariableHeader: Equatable {
    let packetId: UInt16

    init(packetId: UInt16) {
        self.packetId = packetId
    }

    func encode() -> Bytes {
        return encodeUInt16(self.packetId)
    }

    func toString() -> String {
        return "PacketId: \(self.packetId)"
    }
}

struct Unsubscribe: MQTTControlPacket {
    var fixedHeader: FixedHeader
    var varHeader: UnsubscribeVariableHeader
    var payload: UnsubscribePayload

    init(packetId: UInt16, topics: [String]) {
        self.varHeader = .init(packetId: packetId)
        self.payload = .init(topics: topics)
        self.fixedHeader = .init(type: .UNSUBSCRIBE, flags: 2, remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }

    func encode() -> Bytes {
        var bytes: Bytes = []
        bytes.append(contentsOf: self.fixedHeader.encode())
        bytes.append(contentsOf: self.varHeader.encode())
        bytes.append(contentsOf: self.payload.encode())

        return bytes
    }


    func toString() -> String {
        return "\(self.fixedHeader.toString()), \(self.varHeader.toString()), \(self.payload.toString())"
    }
}
