struct SubscribeVariableHeader {
    var packetId: UInt16

    init(packetId: UInt16) {
        self.packetId = packetId
    }

    func encode() -> [UInt8] {
        return encodeUInt16(self.packetId)
    }
}

struct SubscribePayload {
    var topicFilter: String
    var qos: QoS

    init(topicFilter: String, qos: QoS) {
        self.topicFilter = topicFilter
        self.qos = qos
    }

    func encode() -> [UInt8] {
        var data: [UInt8] = []
        data.append(contentsOf: encodeUInt16(UInt16(self.topicFilter.utf8.count)))
        data.append(contentsOf: self.topicFilter.utf8)
        data.append(self.qos.rawValue)

        return data
    }
}

struct MQTTSubscribePacket: MQTTControlPacket {
    var fixedHeader: FixedHeader
    var varHeader: SubscribeVariableHeader
    var payload: SubscribePayload

    init(packetId: UInt16 = 1, topic: String, qos: QoS) {
        self.varHeader = SubscribeVariableHeader(packetId: packetId)
        self.payload = SubscribePayload(topicFilter: topic, qos: qos)
        self.fixedHeader = FixedHeader(type: .SUBSCRIBE, flags: 0b0010, remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }

    func encode() -> [UInt8] {
        var data: [UInt8] = []
        data.append(contentsOf: fixedHeader.encode())
        data.append(contentsOf: varHeader.encode())
        data.append(contentsOf: payload.encode())

        return data
    }
}
