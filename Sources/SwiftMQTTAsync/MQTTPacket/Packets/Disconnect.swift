import NIOCore

public enum DisconnectReasonCode: Byte, Sendable {
    case normalDisconnection = 0x00
    case disconnectWithWillMessage = 0x04
    case unspecifiedError = 0x80
    case malformedPacket = 0x81
    case protocolError = 0x82
    case implementationSpecificError = 0x83
    case notAuthorized = 0x87
    case serverBusy = 0x89
    case serverShuttingDown = 0x8B
    case keepAliveTimeout = 0x8D
    case sessionTakenOver = 0x8E
    case topicFilterInvalid = 0x8F
    case topicNameInvalid = 0x90
    case receiveMaximumExceeded = 0x93
    case topicAliasInvalid = 0x94
    case packetTooLarge = 0x95
    case messageRateTooHigh = 0x96
    case quotaExceeded = 0x97
    case administrativeAction = 0x98
    case payloadFormatInvalid = 0x99
    case retainNotSupported = 0x9A
    case qosNotSupported = 0x9B
    case useAnotherServer = 0x9C
    case serverMoved = 0x9D
    case sharedSubscriptionsNotSupported = 0x9E
    case connectionRateExceeded = 0x9F
    case maximumConnectTime = 0xA0
    case subscriptionIdentifersNotSupported = 0xA1
    case wildcardSubscriptionsNotSupported = 0xA2
}

extension DisconnectReasonCode {
    public func toString() -> String {
        switch self {
        case .normalDisconnection:
            return "normal disconnection"
        case .disconnectWithWillMessage:
            return "disconnect with will message"
        case .unspecifiedError:
            return "unspecified error"
        case .malformedPacket:
            return "malformed packet"
        case .protocolError:
            return "protocol error"
        case .implementationSpecificError:
            return "implementation specific error"
        case .notAuthorized:
            return "not authorized"
        case .serverBusy:
            return "server busy"
        case .serverShuttingDown:
            return "server shutting down"
        case .keepAliveTimeout:
            return "keepalive timeout"
        case .sessionTakenOver:
            return "session taken over"
        case .topicFilterInvalid:
            return "topic filter invalid"
        case .topicNameInvalid:
            return "topic name invalid"
        case .receiveMaximumExceeded:
            return "receive maximum exceeded"
        case .topicAliasInvalid:
            return "topic alias invalid"
        case .packetTooLarge:
            return "packet too large"
        case .messageRateTooHigh:
            return "message rate too high"
        case .quotaExceeded:
            return "quota exceeded"
        case .administrativeAction:
            return "administrative action"
        case .payloadFormatInvalid:
            return "payload format invalid"
        case .retainNotSupported:
            return "retain not supported"
        case .qosNotSupported:
            return "QoS not supported"
        case .useAnotherServer:
            return "use another server"
        case .serverMoved:
            return "server moved"
        case .sharedSubscriptionsNotSupported:
            return "shared subscriptions not supported"
        case .connectionRateExceeded:
            return "connection rate exceeded"
        case .maximumConnectTime:
            return "maximum connect time"
        case .subscriptionIdentifersNotSupported:
            return "subscription"
        case .wildcardSubscriptionsNotSupported:
            return "wildcard subscriptions not supported"
        }
    }
}

public struct DisconnectProperties: Properties {
    public var sessionExpiryInterval: Property?
    public var reasonString: Property?
    public var userProperties: [Property] = []
    public var serverReference: Property?

    internal var properties: [Property?] {
        var p: [Property?] = []

        p.append(sessionExpiryInterval)
        p.append(reasonString)
        for property in userProperties { p.append(property) }
        p.append(serverReference)

        return p
    }

    public init(
        sessionExpiryInterval: UInt32? = nil,
        reasonString: String? = nil,
        userProperties: [(String, String)]? = nil,
        serverReference: String? = nil
    ) {
        if let sessionExpiryInterval {
            self.sessionExpiryInterval = Property.sessionExpiryInterval(sessionExpiryInterval)
        }
        if let reasonString { self.reasonString = Property.reasonString(reasonString) }
        if let userProperties {
            for (key, value) in userProperties {
                self.userProperties.append(Property.userProperty(key, value))
            }
        }
        if let serverReference { self.serverReference = Property.serverReference(serverReference) }
    }

    public init(from properties: [Property]) throws {
        for property in properties {
            switch property.identifier {
            case .sessionExpiryInterval:
                try self.setProperty(&self.sessionExpiryInterval, property)
            case .reasonString:
                try self.setProperty(&self.reasonString, property)
            case .userProperty:
                self.userProperties.append(property)
            case .serverReference:
                try self.setProperty(&self.serverReference, property)
            default:
                throw MQTTError.protocolViolation(
                    .malformedPacket(reason: .incorrectdProperty(inPacket: .DISCONNECT)))
            }
        }
    }
}

public struct DisconnectVariableHeader: Equatable, Sendable {
    public var reasonCode: DisconnectReasonCode?
    public var properties: DisconnectProperties?

    public init(reasonCode: DisconnectReasonCode? = nil, properties: DisconnectProperties? = nil) {
        self.reasonCode = reasonCode
        self.properties = properties
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []
        if let reasonCode { bytes.append(reasonCode.rawValue) }
        bytes.append(contentsOf: self.properties?.encode() ?? [])

        return bytes
    }
}

extension DisconnectVariableHeader {
    public func toString() -> String {
        var s: [String] = []
        if let reasonCode { s.append("Disconnect reason code: \(reasonCode.toString())") }
        if let properties { s.append("Properties: \(properties.toString())") }
        return s.joined(separator: ", ")
    }
}

public struct Disconnect: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var variableHeader: DisconnectVariableHeader

    public init(reasonCode: DisconnectReasonCode? = nil, properties: DisconnectProperties? = nil) {
        self.variableHeader = .init(reasonCode: reasonCode, properties: properties)
        self.fixedHeader = .init(
            type: .DISCONNECT, flags: 0, remainingLength: UInt(self.variableHeader.encode().count))
    }

    public init(bytes: Bytes, version: Version) throws {
        let typeBits: Byte = bytes[0] >> 4
        guard let type = MQTTControlPacketType(rawValue: typeBits) else {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidType(expected: .DISCONNECT, actual: typeBits)))
        }

        if type != .DISCONNECT {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .incorrectType(expected: .DISCONNECT, actual: type)))
        }

        let flags = bytes[0] & 0b00001111
        if flags != 0 {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidFlags(expected: 0, actual: flags)))
        }

        let msglen = try decodeRemainigLength(bytes)

        self.fixedHeader = FixedHeader(
            type: .DISCONNECT, flags: flags, remainingLength: msglen.value)

        // varheader
        let remaining = Bytes(bytes[msglen.length + 1..<bytes.count])
        var reasonCode: DisconnectReasonCode? = nil
        var disconnectProperties: DisconnectProperties? = nil

        switch version {
        case .v5:
            guard let r = DisconnectReasonCode(rawValue: remaining[0]) else {
                throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidReturnCode))
            }
            reasonCode = r

            // Decode properties
            let propslen = try decodeRemainigLength(Bytes(remaining[0..<remaining.count]))
            let props = Bytes(remaining[propslen.length + 1..<remaining.count])
            let properties = try decodeProperties(from: props, length: propslen.value)
            disconnectProperties = try DisconnectProperties(from: properties)
        case .v3:
            if remaining.count > 0 {
                throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidRemainingLength))
            }
        }
        self.variableHeader = .init(
            reasonCode: reasonCode, properties: disconnectProperties)
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []
        bytes.append(contentsOf: self.fixedHeader.encode())
        bytes.append(contentsOf: self.variableHeader.encode())
        return bytes
    }

    public func toString() -> String {
        var s: String = ""
        s.append(self.fixedHeader.toString())
        s.append(self.variableHeader.toString())
        return s
    }
}
