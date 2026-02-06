public struct PubrecVariableHeader: Equatable, Sendable {
    public let packetId: UInt16

    public init(packetId: UInt16) {
      self.packetId = packetId
    }

    public func encode() -> Bytes {
        return encodeUInt16(packetId)
    }

    public func toString() -> String {
        return "\(self.packetId)"
    }
}

public struct Pubrec: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: PubrecVariableHeader
}

public extension Pubrec {
    init(packetId: UInt16) {
        self.fixedHeader = .init(type: .PUBREC, flags: 0, remainingLength: 2)
        self.varHeader = .init(packetId: packetId)
    }

    init(bytes: Bytes) throws {
        let typeBytes = bytes[0] >> 4
        guard let type = MQTTControlPacketType(rawValue: bytes[0] >> 4) else {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidType(expected: .PUBREC, actual: typeBytes)))
        }

        if type != .PUBREC {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .incorrectType(expected: .PUBCOMP, actual: type)))
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
}

public extension Pubrec {
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
