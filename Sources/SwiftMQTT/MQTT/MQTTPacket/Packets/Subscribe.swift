struct MQTTSubscribePacket: MQTTControlPacket {
    var fixedHeader: FixedHeader
    var varHeader: [UInt8]
    var payload: [UInt8]

    init(messageId: UInt16, topic: String) {
        self.varHeader = encodeUInt16(messageId)
        let encodedTopic = Array(topic.utf8)
        self.payload = encodeUInt16(UInt16(encodedTopic.count))
        self.payload.append(contentsOf: encodedTopic)
        self.payload.append(0x00) // QoS 0
        self.fixedHeader = FixedHeader(type: .SUBSCRIBE, flags: 0b0010, remainingLength: UInt(self.varHeader.count + self.payload.count))
    }

    func encode() -> [UInt8] {
        var data: [UInt8] = []
        data.append(contentsOf: fixedHeader.encode())
        data.append(contentsOf: varHeader)
        data.append(contentsOf: payload)

        return data
    }
}
