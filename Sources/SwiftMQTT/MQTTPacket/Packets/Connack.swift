public enum ConnectReturnCode: UInt8, Sendable {
    case ConnectionAccepted = 0
    case UnnacceptableProtocolVersion = 1
    case IdentifierRejected = 2
    case ServerUnavailable = 3
    case BadAuth = 4
    case Unauthorized = 5
    case Reserved

    public func toString() -> String {
        let status =
            switch self {
            case .ConnectionAccepted:
                "CONNECTION ACCEPTED"
            case .UnnacceptableProtocolVersion:
                "UNNACCEPTABLE PROTOCOL VERSION"
            case .IdentifierRejected:
                "IDENTIFIER REJECTED"
            case .ServerUnavailable:
                "SERVER UNAVAIALBLE"
            case .BadAuth:
                "BAD AUTH"
            case .Unauthorized:
                "UNAUTHORIZED"
            case .Reserved:
                "RESERVED"
            }

        return "Return code: \(status)"
    }
}

public struct ConnackVariableHeader: Equatable, Sendable {
    let sessionPresent: UInt8
    let connectReturnCode: ConnectReturnCode

    public init(sessionPresent: UInt8, connectReturnCode: ConnectReturnCode) {
        self.sessionPresent = sessionPresent
        self.connectReturnCode = connectReturnCode
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []

        bytes.append(self.sessionPresent)
        bytes.append(self.connectReturnCode.rawValue)

        return bytes
    }

    public func toString() -> String {
        return "Session present: \(self.sessionPresent), \(self.connectReturnCode.toString())"
    }
}

public struct Connack: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: ConnackVariableHeader

}

// MARK: Init
extension Connack {
    // TODO: parse flags
    public init(bytes: Bytes) throws {
        let typeBits: Byte = bytes[0] >> 4
        guard let type = MQTTControlPacketType(rawValue: typeBits) else {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidType(expected: .CONNACK, actual: typeBits)))
        }

        if type != .CONNACK {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .incorrectType(expected: .CONNACK, actual: type)))
        }

        let flags = bytes[0] & 0b00001111
        if flags != 0 {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidFlags(expected: 0, actual: flags)))
        }

        if bytes[1] != 2 {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidRemainingLenght))
        }

        self.fixedHeader = FixedHeader(type: .CONNACK, flags: flags, remainingLength: 2)

        if bytes[2] != 0 && bytes[2] != 1 {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .reservedBitModified))
        }

        guard let connectionReturnCode = ConnectReturnCode(rawValue: bytes[3]) else {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidReturnCode))
        }

        self.varHeader = ConnackVariableHeader(
            sessionPresent: bytes[2], connectReturnCode: connectionReturnCode)
    }

    public init(returnCode: ConnectReturnCode, sessionPresent: Bool) {
        self.fixedHeader = FixedHeader(type: .CONNACK, flags: 0, remainingLength: 2)
        self.varHeader = ConnackVariableHeader(
            sessionPresent: sessionPresent ? 1 : 0, connectReturnCode: returnCode)
    }
}

// MARK: Utils
extension Connack {
    public func encode() -> Bytes {
        var bytes: Bytes = []

        bytes.append(contentsOf: self.fixedHeader.encode())
        bytes.append(contentsOf: self.varHeader.encode())

        return bytes
    }

    public func toString() -> String {
        return
            "\(self.fixedHeader.toString()), \(self.varHeader.toString())"
    }
}
