public struct UnsubackProperties: Properties {
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

extension UnsubackProperties {
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
                    .malformedPacket(reason: .incorrectdProperty(inPacket: .UNSUBACK)))
            }
        }
    }
}

public enum UnsubackReasonCode: Byte, Equatable, Sendable {
    case success = 0x00
    case noSubscriptionExisted = 0x11
    case unspecifiedError = 0x80
    case implementationSpecificError = 0x83
    case notAuthorized = 0x87
    case topicFilterInvalid = 0x8f
    case packetIdentifierInUse = 0x91

    public func toString() -> String {
        switch self {
        case .success:
            return "SUCCESS"
        case .noSubscriptionExisted:
            return "NO SUBSCRIPTION EXISTED"
        case .unspecifiedError:
            return "UNSPECIFIED ERROR"
        case .implementationSpecificError:
            return "IMPLEMENTAION SPECIFIC ERROR"
        case .notAuthorized:
            return "NOT AUTHORIZED"
        case .topicFilterInvalid:
            return "TOPIC FILTER INVALID"
        case .packetIdentifierInUse:
            return "PACKET IDENTIFIER IN USE"
        }
    }
}

public struct UnsubackPayload: Equatable, Sendable {
    public var reasonCodes: [UnsubackReasonCode]

    public init(reasonCodes: [UnsubackReasonCode]) {
        self.reasonCodes = reasonCodes
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []
        for reasonCode in self.reasonCodes {
            bytes.append(reasonCode.rawValue)
        }

        return bytes
    }

    public func toString() -> String {
        return "Reason codes: \(self.reasonCodes.map { $0.toString() }.joined(separator: ", "))"
    }
}

public struct UnsubackVariableHeader: Equatable, Sendable {
    public let packetId: UInt16
    public var properties: UnsubackProperties?

    public init(packetId: UInt16, properties: UnsubackProperties? = nil) {
        self.packetId = packetId
        self.properties = properties
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []
        bytes.append(contentsOf: encodeUInt16(self.packetId))
        bytes.append(contentsOf: self.properties?.encode() ?? [])
        return bytes
    }

    public func toString() -> String {
        var s = "Packet ID: \(self.packetId)"
        if let properties { s.append(", Properties: \(properties.toString())") }
        return s
    }
}

public struct Unsuback: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: UnsubackVariableHeader
    public var payload: UnsubackPayload?

    public init(
        packetId: UInt16, properties: UnsubackProperties? = nil,
        reasonCodes: [UnsubackReasonCode]? = nil
    ) {
        var msgLen: UInt = 0
        self.varHeader = .init(packetId: packetId, properties: properties)
        msgLen += UInt(self.varHeader.encode().count)
        if let reasonCodes {
            msgLen += UInt(reasonCodes.count)
            self.payload = .init(reasonCodes: reasonCodes)
        }
        self.fixedHeader = .init(type: .UNSUBACK, flags: 0, remainingLength: msgLen)
    }

    public init(bytes: Bytes, version: Version) throws {
        let typeBytes = bytes[0] >> 4
        guard let type = MQTTControlPacketType(rawValue: typeBytes) else {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidType(expected: .UNSUBACK, actual: typeBytes)))
        }

        if type != .UNSUBACK {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .incorrectType(expected: .UNSUBACK, actual: type)))
        }

        let flags = bytes[0] & 0b00001111
        if flags != 0 {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidFlags(expected: 0, actual: flags)))
        }

        // let msgLen = bytes[1]
        let msgLen = try decodeRemainigLength(bytes)
        let remaining = Bytes(bytes[msgLen.length + 1..<bytes.count])
        let packetIdMSB = remaining[0]
        let packetIdLSB = remaining[1]
        let packetId = (UInt16(packetIdMSB) << 8) | UInt16(packetIdLSB)

        var unsubackProperties: UnsubackProperties? = nil
        var unsubackReasonCodes: [UnsubackReasonCode] = []

        if case .v5 = version {
            let varHeaderBytes: Bytes = Bytes(remaining[1..<remaining.count])
            // Decode properties
            let propslen = try decodeRemainigLength(varHeaderBytes)
            let props = Bytes(varHeaderBytes[propslen.length + 1..<2 + Int(propslen.value)])
            let properties = try decodeProperties(from: props, length: propslen.value)
            unsubackProperties = try .init(from: properties)

            // decode reason codes
            let reasonCodeBytes: Bytes = Bytes(
                varHeaderBytes[2 + Int(propslen.value)..<varHeaderBytes.count])
            for byte in reasonCodeBytes {
                guard let reasonCode = UnsubackReasonCode(rawValue: byte) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidReturnCode))
                }
                unsubackReasonCodes.append(reasonCode)
            }
            self.payload = .init(reasonCodes: unsubackReasonCodes)
        }

        self.fixedHeader = .init(type: type, flags: flags, remainingLength: msgLen.value)
        self.varHeader = .init(packetId: packetId, properties: unsubackProperties)
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []
        bytes.append(contentsOf: self.fixedHeader.encode())
        bytes.append(contentsOf: self.varHeader.encode())
        bytes.append(contentsOf: self.payload?.encode() ?? [])

        return bytes
    }

    public func toString() -> String {
        var s: String = "\(self.fixedHeader.toString()), \(self.varHeader.toString())"
        if let payload { s.append(", \(payload.toString())") }
        return s
    }
}
