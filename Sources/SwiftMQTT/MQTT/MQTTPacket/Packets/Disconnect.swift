struct MQTTDisconnectPacket: MQTTControlPacket {
    var fixedHeader: FixedHeader

    init() {
        self.fixedHeader = .init(type: .DISCONNECT, flags: 0, remainingLength: 0)
    }

    func encode() -> ByteBuffer {
        return self.fixedHeader.encode()
    }

    func toString() -> String {
        return self.fixedHeader.toString()
    }
}
