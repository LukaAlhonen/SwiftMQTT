public struct PubackVarableHeader: Equatable, Sendable {
    let packetId: UInt16

    public init(packetId: UInt16) {
        self.packetId = packetId
    }

    public func encode() -> Bytes {
        return encodeUInt16(self.packetId)
    }

    public func toString() -> String {
        return "Packet ID: \(self.packetId)"
    }
}

public struct Puback: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: PubackVarableHeader
}

extension Puback {
    public init(packetId: UInt16) {
        self.fixedHeader = .init(type: .PUBACK, flags: 0, remainingLength: 2)
        self.varHeader = .init(packetId: packetId)
    }

    public init(bytes: Bytes) throws {
        let typeBytes = bytes[0] >> 4
        guard let type = MQTTControlPacketType(rawValue: typeBytes) else {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidType(expected: .PUBACK, actual: typeBytes)))
        }

        if type != .PUBACK {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .incorrectType(expected: .PUBACK, actual: type)))
        }

        let flags = bytes[0] & 0b00001111
        if flags != 0 {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidFlags(expected: 0, actual: flags)))
        }

        let msgLen = bytes[1]
        let packetIdMSB = bytes[2]
        let packetIdLSB = bytes[3]
        let packetId = (UInt16(packetIdMSB) << 8) | UInt16(packetIdLSB)

        self.fixedHeader = .init(type: type, flags: flags, remainingLength: UInt(msgLen))
        self.varHeader = .init(packetId: packetId)
    }
}

extension Puback {
    public func encode() -> Bytes {
        var bytes: Bytes = []
        bytes.append(contentsOf: self.fixedHeader.encode())
        bytes.append(contentsOf: self.varHeader.encode())

        return bytes
    }

    public func toString() -> String {
        return "\(self.fixedHeader.toString()), \(self.varHeader.toString())"
    }
}
