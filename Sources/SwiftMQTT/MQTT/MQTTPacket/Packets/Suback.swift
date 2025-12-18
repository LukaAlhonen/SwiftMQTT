struct MQTTSubackPacket: MQTTControlPacket {
    var fixedHeader: FixedHeader
    var varHeader: [UInt8]
    var payload: [UInt8]

    init(_ data: [UInt8]) {
        let headerFlags = data[0]
        if (headerFlags != MQTTControlPacketType.SUBACK.rawValue) {
            fatalError("Incorrect packet type: \(String(format: "%02X", headerFlags))")
        }

        let (value, length) = decodeRemainigLength(data)
        self.fixedHeader = FixedHeader(type: .SUBACK, flags: headerFlags & 0x0F, remainingLength: value)

        let varHeaderStart = length+1
        let varHeaderStop = length+2
        self.varHeader = Array(data[varHeaderStart...varHeaderStop])
        self.payload = Array(data[varHeaderStop+1..<length])
    }

    func encode() -> [UInt8] {
        return [0x00]
    }
}
