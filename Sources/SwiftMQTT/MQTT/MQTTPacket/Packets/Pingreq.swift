struct MQTTPingreqPacket: MQTTControlPacket {
    var fixedHeader: FixedHeader

    init() {
        self.fixedHeader = FixedHeader(type: .PINGREQ, flags: 0, remainingLength: 0)
    }

    func encode() -> [UInt8] {
        return self.fixedHeader.encode()
    }

    func toString() -> String {
        return "PINGREQ"
    }
}
