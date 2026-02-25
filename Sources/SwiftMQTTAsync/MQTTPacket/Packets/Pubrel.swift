import NIOCore

public enum PubrelReasonCode: Byte, Equatable, Sendable {
    case success = 0x00
    case packetIdentifierNotFound = 0x92
}

extension PubrelReasonCode {
    public func toString() -> String {
        switch self {
        case .success:
            return "SUCCESS"
        case .packetIdentifierNotFound:
            return "PACKET IDENTIFIER NOT FOUND"
        }
    }
}

public struct PubrelProperties: Properties {
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

extension PubrelProperties {
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
                    .malformedPacket(reason: .incorrectdProperty(inPacket: .PUBREL)))
            }
        }
    }
}

public struct PubrelVariableHeader: Equatable, Sendable {
    public let packetId: UInt16
    public var reasonCode: PubrelReasonCode?
    public var properties: PubrelProperties?

    public init(
        packetId: UInt16, reasonCode: PubrelReasonCode? = nil, properties: PubrelProperties? = nil
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

public struct Pubrel: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: PubrelVariableHeader
}

extension Pubrel {
    public init(
        packetId: UInt16, reasonCode: PubrelReasonCode? = nil, properties: PubrelProperties? = nil
    ) {
        self.varHeader = .init(packetId: packetId, reasonCode: reasonCode, properties: properties)
        self.fixedHeader = .init(
            type: .PUBREL, flags: 2, remainingLength: UInt(self.varHeader.encode().count))
    }

    public init(bytes: Bytes, version: Version) throws {
        let typeBytes = bytes[0] >> 4
        guard let type = MQTTControlPacketType(rawValue: typeBytes) else {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidType(expected: .PUBREL, actual: typeBytes)))
        }

        if type != .PUBREL {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .incorrectType(expected: .PUBREL, actual: type)))
        }

        let flags = bytes[0] & 0b00001111
        if flags != 2 {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidFlags(expected: 2, actual: flags)))
        }

        let msgLen = try decodeRemainigLength(bytes)
        let varHeaderBytes = Bytes(bytes[msgLen.length + 1..<bytes.count])
        let packetIdMSB = varHeaderBytes[0]
        let packetIdLSB = varHeaderBytes[1]
        let packetId = (UInt16(packetIdMSB) << 8) | UInt16(packetIdLSB)
        let remaining: Bytes = Bytes(varHeaderBytes[2..<varHeaderBytes.count])

        var pubrelReasonCode: PubrelReasonCode? = nil
        var pubrelProperties: PubrelProperties? = nil

        switch version {
        case .v3:
            if msgLen.value != 2 {
                throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidRemainingLength))
            }
        case .v5:
            if msgLen.value > 2 {
                // Decode reason code
                guard let reasonCode: PubrelReasonCode = PubrelReasonCode(rawValue: remaining[0])
                else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidReturnCode))
                }
                pubrelReasonCode = reasonCode

                // Decode properties
                let propslen = try decodeRemainigLength(Bytes(remaining[0..<remaining.count]))
                let props = Bytes(remaining[propslen.length + 1..<2 + Int(propslen.value)])
                let properties = try decodeProperties(from: props, length: propslen.value)
                pubrelProperties = try .init(from: properties)
            }
        }

        self.fixedHeader = .init(type: type, flags: flags, remainingLength: msgLen.value)
        self.varHeader = .init(
            packetId: packetId, reasonCode: pubrelReasonCode, properties: pubrelProperties)
    }
}

extension Pubrel {
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
