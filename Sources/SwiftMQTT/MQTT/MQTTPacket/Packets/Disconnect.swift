struct Disconnect: MQTTControlPacket {
    var fixedHeader: FixedHeader

    init() {
        self.fixedHeader = .init(type: .DISCONNECT, flags: 0, remainingLength: 0)
    }

    func encode() -> Bytes {
        return self.fixedHeader.encode()
    }

    func toString() -> String {
        return self.fixedHeader.toString()
    }
}
