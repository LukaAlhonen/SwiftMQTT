public enum PubackReasonCode: Byte, Equatable, Sendable {
    case success = 0x00
    case noMatchingSubscribers = 0x10
    case unspecifiedError = 0x80
    case implementationSpecificError = 0x83
    case notAuthorized = 0x87
    case topicNameInvalid = 0x90
    case packetIdentifierInUse = 0x91
    case quotaExceeded = 0x97
    case payloadFormatInvalid = 0x99
}

public struct PubackProperties: Properties {
    public var reasonString: Property?
    public var userProperties: [Property] = []

    internal var properties: [Property?] {
        var p: [Property?] = []
        p.append(self.reasonString)
        for property in self.userProperties { p.append(property) }
        return p
    }
}

public extension PubackProperties {
    init(reasonString: String? = nil, userProperties: [(String, String)]? = nil) {
        if let reasonString { self.reasonString = Property.reasonString(reasonString)}
        if let userProperties {
            for (key, value) in userProperties {
                self.userProperties.append(Property.userProperty(key, value))
            }
        }
    }

    init(from properties: [Property]) throws {
        for property in properties {
            switch property.identifier {
                case .reasonString:
                    try self.setProperty(&self.reasonString, property)
                case .userProperty:
                    self.userProperties.append(property)
                default:
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .incorrectdProperty(inPacket: .PUBACK)))
            }
        }
    }
}

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

    public init(bytes: Bytes, version: Version) throws {
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
