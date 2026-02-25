import NIOCore

public enum PubcompReasonCode: Byte, Equatable, Sendable {
    case success = 0x00
    case packetIdentifierNotFound = 0x92
}

extension PubcompReasonCode {
    public func toString() -> String {
        switch self {
        case .success:
            return "SUCCESS"
        case .packetIdentifierNotFound:
            return "PACKET IDENTIFIER NOT FOUND"
        }
    }
}

public struct PubcompProperties: Properties {
    public var reasonString: Property?
    public var userProperties: [Property] = []

    internal var properties: [Property?] {
        var p: [Property?] = []
        p.append(self.reasonString)
        for property in self.userProperties {
            p.append(property)
        }

        return p
    }
}

extension PubcompProperties {
    public init(reasonString: String? = nil, userProperties: [(String, String)]? = nil) {
        if let reasonString { self.reasonString = Property.reasonString(reasonString) }
        if let userProperties {
            for (key, value) in userProperties {
                self.userProperties.append(Property.userProperty(key, value))
            }
        }
    }

    public init(from properties: [Property]) throws {
        for property in properties {
            switch property.identifier {
            case .reasonString:
                try self.setProperty(&self.reasonString, property)
            case .userProperty:
                self.userProperties.append(property)
            default:
                throw MQTTError.protocolViolation(
                    .malformedPacket(reason: .incorrectdProperty(inPacket: .PUBACK)))
            }
        }
    }
}

public struct PubcompVariableHeader: Equatable, Sendable {
    public let packetId: UInt16
    public var reasonCode: PubcompReasonCode?
    public var properties: PubcompProperties?

    public init(
        packetId: UInt16, reasonCode: PubcompReasonCode? = nil, properties: PubcompProperties? = nil
    ) {
        self.packetId = packetId
        self.reasonCode = reasonCode
        self.properties = properties
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []

        bytes.append(contentsOf: encodeUInt16(self.packetId))
        if let reasonCode { bytes.append(reasonCode.rawValue) }
        bytes.append(contentsOf: self.properties?.encode() ?? [])

        return bytes
    }

    public func toString() -> String {
        var s: String = "Packet ID: \(self.packetId)"

        if let reasonCode { s.append(", Reason code: \(reasonCode.toString())") }
        if let properties { s.append(", Properties: \(properties.toString())") }

        return s
    }
}

public struct Pubcomp: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: PubcompVariableHeader
}

extension Pubcomp {
    public init(
        packetId: UInt16, reasonCode: PubcompReasonCode? = nil, properties: PubcompProperties? = nil
    ) {
        self.varHeader = .init(packetId: packetId, reasonCode: reasonCode, properties: properties)
        self.fixedHeader = .init(
            type: .PUBCOMP, flags: 0, remainingLength: UInt(self.varHeader.encode().count))
    }

    public init(bytes: Bytes, version: Version) throws {
        let typeBytes = bytes[0] >> 4
        guard let type = MQTTControlPacketType(rawValue: typeBytes) else {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidType(expected: .PUBCOMP, actual: typeBytes)))
        }

        if type != .PUBCOMP {
            // throw MQTTError.DecodePacketError(message: "Incorrect packet type, expected PUBCOMP, received: \(type.toString())")
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .incorrectType(expected: .PUBCOMP, actual: type)))
        }

        let flags = bytes[0] & 0b00001111
        if flags != 0 {
            // throw MQTTError.DecodePacketError(message: "Invalid flags")
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidFlags(expected: 0, actual: flags)))
        }

        let msgLen = try decodeRemainigLength(bytes)
        let varHeaderBytes = Bytes(bytes[msgLen.length + 1..<bytes.count])
        let packetIdMSB = varHeaderBytes[0]
        let packetIdLSB = varHeaderBytes[1]
        let packetId = (UInt16(packetIdMSB) << 8) | UInt16(packetIdLSB)
        let remaining: Bytes = Bytes(varHeaderBytes[2..<varHeaderBytes.count])

        var pubcompReasonCode: PubcompReasonCode? = nil
        var pubcompProperties: PubcompProperties? = nil

        switch version {
        case .v3:
            if remaining.count > 0 {
                throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidRemainingLength))
            }
        case .v5:
            if msgLen.value > 2 {
                // Decode reason code
                guard let reasonCode: PubcompReasonCode = PubcompReasonCode(rawValue: remaining[0])
                else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidReturnCode))
                }
                pubcompReasonCode = reasonCode

                // Decode properties
                let propslen = try decodeRemainigLength(Bytes(remaining[0..<remaining.count]))
                let props = Bytes(remaining[propslen.length + 1..<2 + Int(propslen.value)])
                let properties = try decodeProperties(from: props, length: propslen.value)
                pubcompProperties = try .init(from: properties)
            }
        }

        self.fixedHeader = .init(type: type, flags: flags, remainingLength: msgLen.value)
        self.varHeader = .init(
            packetId: packetId, reasonCode: pubcompReasonCode, properties: pubcompProperties)
    }
}

extension Pubcomp {
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
