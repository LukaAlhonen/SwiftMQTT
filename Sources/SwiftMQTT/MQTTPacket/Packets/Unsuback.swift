public struct UnsubackVariableHeader: Equatable, Sendable {
    public let packetId: UInt16

    public init(packetId: UInt16) {
        self.packetId = packetId
    }

    public func encode() -> Bytes {
        return encodeUInt16(self.packetId)
    }

    public func toString() -> String {
        return "PacketId: \(self.packetId)"
    }
}

public struct Unsuback: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: UnsubackVariableHeader

    public init(packetId: UInt16) {
        self.varHeader = .init(packetId: packetId)
        self.fixedHeader = .init(type: .UNSUBACK, flags: 0, remainingLength: 2)
    }

    public init(bytes: Bytes) throws {
        let typeBytes = bytes[0] >> 4
        guard let type = MQTTControlPacketType(rawValue: typeBytes) else {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidType(expected: .UNSUBACK, actual: typeBytes)))
        }

        if type != .UNSUBACK {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .incorrectType(expected: .UNSUBACK, actual: type)))
        }

        let flags = bytes[0] & 0b00001111
        if flags != 0 {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidFlags(expected: 0, actual: flags)))
        }

        let msgLen = bytes[1]
        let packetIdMSB = bytes[2]
        let packetIdLSB = bytes[3]
        let packetId = (UInt16(packetIdMSB) << 8) | UInt16(packetIdLSB)

        self.fixedHeader = .init(type: type, flags: flags, remainingLength: UInt(msgLen))
        self.varHeader = .init(packetId: packetId)
    }

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
