struct PubrecVariableHeader: Equatable {
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

    init(bytes: ByteBuffer) throws {
        guard let type = MQTTControlPacketType(rawValue: bytes[0] >> 4) else {
            throw MQTTError.DecodePacketError(message: "Invalid mqtt packet type")
        }

        if type != .PUBREC {
            throw MQTTError.DecodePacketError(message: "Incorrect packet type, expected PUBCOMP, received: \(type.toString())")
        }

        let flags = bytes[0] & 0b00001111
        if flags != 0 {
            throw MQTTError.DecodePacketError(message: "Invalid flags")
        }

        let msgLen = bytes[1]
        let packetIdMSB = bytes[2]
        let packetIdLSB = bytes[3]
        let packetId = (UInt16(packetIdMSB) << 8) | UInt16(packetIdLSB)

        self.fixedHeader = .init(type: type, flags: flags, remainingLength: UInt(msgLen))
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
