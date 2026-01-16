struct PubrecVariableHeader {
    let packetId: UInt16

    init(packetId: UInt16) {
      self.packetId = packetId
    }

    func encode() -> ByteBuffer {
        return encodeUInt16(packetId)
    }

    func toString() -> String {
        return "\(self.packetId)"
    }
}

struct MQTTPubrecPacket: MQTTControlPacket {
    var fixedHeader: FixedHeader
    var varHeader: PubrecVariableHeader

    init(packetId: UInt16) {
        self.fixedHeader = .init(type: .PUBREC, flags: 0, remainingLength: 2)
        self.varHeader = .init(packetId: packetId)
    }

    func encode() -> ByteBuffer {
        var bytes: ByteBuffer = []

        bytes.append(contentsOf: self.fixedHeader.encode())
        bytes.append(contentsOf: self.varHeader.encode())

        return bytes
    }


    func toString() -> String {
        return "\(self.fixedHeader.toString()), \(self.varHeader.toString())"
    }
}
