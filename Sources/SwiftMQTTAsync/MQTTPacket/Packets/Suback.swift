public enum SubackReturnCode: UInt8, Sendable {
    case QoS0 = 0x00
    case QoS1 = 0x01
    case QoS2 = 0x02
    case Rejected = 0x80

    public func toString() -> String {
        switch self {
        case .QoS0:
            return "QoS 0"
        case .QoS1:
            return "QoS 1"
        case .QoS2:
            return "QoS 2"
        case .Rejected:
            return "Rejected"
        }
    }
}

public struct SubackPayload: Equatable, Sendable {
    public let returnCodes: [SubackReturnCode]

    public init(bytes: Bytes) throws {
        var codes: [SubackReturnCode] = []
        for byte in bytes {
            guard let code = SubackReturnCode(rawValue: byte) else {
                throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidReturnCode))
            }
            codes.append(code)
        }
        self.returnCodes = codes
    }

    public init(returnCodes: [SubackReturnCode]) {
        self.returnCodes = returnCodes
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []

        for code in self.returnCodes {
            bytes.append(code.rawValue)
        }

        return bytes
    }

    public func toString() -> String {
        let codeString = self.returnCodes.map { $0.toString() }.joined(separator: ", ")
        return "Return codes: [\(codeString)]"
    }
}

public struct SubackVariableHeader: Equatable, Sendable {
    public let packetId: UInt16

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

public struct Suback: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: SubackVariableHeader
    public var payload: SubackPayload
}

extension Suback {
    public init(bytes: Bytes) throws {
        let typeBytes = bytes[0] >> 4
        guard let type = MQTTControlPacketType(rawValue: typeBytes) else {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidType(expected: .SUBACK, actual: typeBytes)))
        }

        if type != .SUBACK {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .incorrectType(expected: .SUBACK, actual: type)))
        }

        let flags = bytes[0] & 0b00001111
        if flags != 0 {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidFlags(expected: 0, actual: flags)))
        }

        let packetId = (UInt16(bytes[2]) << 8) | UInt16(bytes[3])
        self.varHeader = SubackVariableHeader(packetId: packetId)
        self.payload = try SubackPayload(bytes: Bytes(bytes[4..<bytes.count]))
        self.fixedHeader = FixedHeader(
            type: type, flags: flags,
            remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }

    public init(packetId: UInt16, returnCodes: [SubackReturnCode]) {
        self.varHeader = SubackVariableHeader(packetId: packetId)
        self.payload = SubackPayload(returnCodes: returnCodes)
        self.fixedHeader = FixedHeader(
            type: .SUBACK, flags: 0,
            remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }
}

extension Suback {
    public func encode() -> Bytes {
        var bytes: Bytes = []
        bytes.append(contentsOf: self.fixedHeader.encode())
        bytes.append(contentsOf: self.varHeader.encode())
        bytes.append(contentsOf: self.payload.encode())

        return bytes
    }

    public func toString() -> String {
        return
            "\(self.fixedHeader.toString()), \(self.varHeader.toString()), \(self.payload.toString())"
    }
}
