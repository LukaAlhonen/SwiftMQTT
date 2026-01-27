struct TopicFilter: Hashable {
    let topic: String
    let qos: QoS
}

struct SubscribeVariableHeader: Equatable {
    var packetId: UInt16

    init(packetId: UInt16) {
        self.packetId = packetId
    }

    func encode() -> ByteBuffer {
        return encodeUInt16(self.packetId)
    }

    func toString() -> String {
        return "packetId: \(self.packetId)"
    }
}

struct SubscribePayload: Equatable {
    var topics: [TopicFilter]

    init(topics: [TopicFilter]) {
        self.topics = topics
    }

    func encode() -> ByteBuffer {
        var data: ByteBuffer = []

        for topicFilter in self.topics {
            data.append(contentsOf: encodeUInt16(UInt16(topicFilter.topic.utf8.count)))
            data.append(contentsOf: topicFilter.topic.utf8)
            data.append(topicFilter.qos.rawValue)
        }

        return data
    }

    func toString() -> String {
        let s = self.topics.map { "topic: \($0.topic), QoS: \($0.qos)"}.joined(separator: ", ")
        return s
    }
}

struct MQTTSubscribePacket: MQTTControlPacket {
    var fixedHeader: FixedHeader
    var varHeader: SubscribeVariableHeader
    var payload: SubscribePayload

    init(packetId: UInt16 = 1, topics: [TopicFilter]) {
        self.varHeader = SubscribeVariableHeader(packetId: packetId)
        self.payload = SubscribePayload(topics: topics)
        self.fixedHeader = FixedHeader(type: .SUBSCRIBE, flags: 0b0010, remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }

    func encode() -> ByteBuffer {
        var data: ByteBuffer = []
        data.append(contentsOf: fixedHeader.encode())
        data.append(contentsOf: varHeader.encode())
        data.append(contentsOf: payload.encode())

        return data
    }

    func toString() -> String {
        return "SUBSCRIBE [\(self.varHeader.toString())] [\(self.payload.toString())]"
    }
}
