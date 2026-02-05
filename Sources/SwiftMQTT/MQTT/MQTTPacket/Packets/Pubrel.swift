struct PubrelVariableHeader: Equatable {
    let packetId: UInt16

    init(packetId: UInt16) {
        self.packetId = packetId
    }

    func encode() -> Bytes {
        return encodeUInt16(self.packetId)
    }

    func toString() -> String {
        return "\(self.packetId)"
    }
}

struct Pubrel: MQTTControlPacket {
    var fixedHeader: FixedHeader
    var varHeader: PubrelVariableHeader

    init(packetId: UInt16) {
        self.fixedHeader = .init(type: .PUBREL, flags: 2, remainingLength: 2)
        self.varHeader = .init(packetId: packetId)
    }

    init(bytes: Bytes) throws {
        let typeBytes = bytes[0] >> 4
        guard let type = MQTTControlPacketType(rawValue: typeBytes) else {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidType(expected: .PUBREL, actual: typeBytes)))
        }

        if type != .PUBREL {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .incorrectType(expected: .PUBREL, actual: type)))
        }

        let flags = bytes[0] & 0b00001111
        if flags != 2 {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidFlags(expected: 2, actual: flags)))
        }

        let packetIdMSB = bytes[2]
        let packetIdLSB = bytes[3]
        let packetId = (UInt16(packetIdMSB) << 8) | UInt16(packetIdLSB)

        self.fixedHeader = .init(type: type, flags: flags, remainingLength: 2)
        self.varHeader = .init(packetId: packetId)
    }

    func encode() -> Bytes {
        var bytes: Bytes = []

        bytes.append(contentsOf: self.fixedHeader.encode())
        bytes.append(contentsOf: self.varHeader.encode())

        return bytes
    }


    func toString() -> String {
        return "\(self.fixedHeader.toString()), \(self.varHeader.toString())"
    }
}
