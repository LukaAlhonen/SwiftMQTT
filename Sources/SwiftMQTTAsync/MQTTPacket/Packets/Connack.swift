import NIOCore

public enum ConnectReturnCode: Byte, Sendable {
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

public enum ConnectReasonCode: Byte, Sendable {
    case success = 0x00
    case unspecifiedError = 0x80
    case malformedPacket = 0x81
    case protocolError = 0x82
    case implementationSpecificError = 0x83
    case unsupportedProtocolVersion = 0x84
    case clientIdentifierNotValid = 0x85
    case badUsernameOrPassword = 0x86
    case notAuthorized = 0x87
    case serverUnavaliable = 0x88
    case serverBusy = 0x89
    case banned = 0x8a
    case badAuthenticationMethod = 0x8c
    case topicNameInvalid = 0x90
    case packetTooLarge = 0x95
    case quotaExceeded = 0x97
    case payloadFormatInvalid = 0x99
    case retainNotSupported = 0x9a
    case qosNotSupported = 0x9b
    case useAnotherServer = 0x9c
    case serverMoved = 0x9d
    case connectionRateExceeded = 0x9f

    public func toString() -> String {
        return "\(self)"
    }
}

public struct ConnackProperties: Properties {
    public var sessionExpiryInterval: Property? = nil
    public var receiveMaximum: Property? = nil
    public var maximumQoS: Property? = nil
    public var retainAvailable: Property? = nil
    public var maximumPacketSize: Property? = nil
    public var assignedClientIdentifier: Property? = nil
    public var topicAliasMaximum: Property? = nil
    public var reasonString: Property? = nil
    public var userProperties: [Property] = []
    public var wildcardSubscriptionAvailable: Property? = nil
    public var subscriptionIdentifierAvailable: Property? = nil
    public var sharedSubscriptionAvailable: Property? = nil
    public var serverKeepalive: Property? = nil
    public var responseInformation: Property? = nil
    public var serverReference: Property? = nil
    public var authenticationMethod: Property? = nil
    public var authenticationData: Property? = nil

    internal var properties: [Property?] {
        var p: [Property?] = []

        p.append(sessionExpiryInterval)
        p.append(receiveMaximum)
        p.append(maximumQoS)
        p.append(retainAvailable)
        p.append(maximumPacketSize)
        p.append(assignedClientIdentifier)
        p.append(topicAliasMaximum)
        p.append(reasonString)
        for property in userProperties { p.append(property) }
        p.append(wildcardSubscriptionAvailable)
        p.append(subscriptionIdentifierAvailable)
        p.append(sharedSubscriptionAvailable)
        p.append(serverKeepalive)
        p.append(responseInformation)
        p.append(serverReference)
        p.append(authenticationMethod)
        p.append(authenticationData)

        return p
    }

    public init(
        sessionExpiryInterval: UInt32? = nil,
        receiveMaximum: UInt16? = nil,
        maximumQoS: Byte? = nil,
        retainAvailable: Byte? = nil,
        maximumPacketSize: UInt32? = nil,
        assignedClientIdentifier: String? = nil,
        topicAliasMaximum: UInt16? = nil,
        reasonString: String? = nil,
        userProperties: [(String, String)]? = nil,
        wildcardSubscriptionAvailable: Byte? = nil,
        subscriptionIdentifierAvailable: Byte? = nil,
        sharedSubscriptionAvailable: Byte? = nil,
        serverKeepalive: UInt16? = nil,
        responseInformation: String? = nil,
        serverReference: String? = nil,
        authenticationMethod: String? = nil,
        authenticationData: Bytes? = nil
    ) {
        if let sessionExpiryInterval { self.sessionExpiryInterval = Property.sessionExpiryInterval(sessionExpiryInterval)}
        if let receiveMaximum { self.receiveMaximum = Property.receiveMaximum(receiveMaximum)}
        if let maximumQoS { self.maximumQoS = Property.maximumQoS(maximumQoS)}
        if let retainAvailable { self.retainAvailable = Property.retainAvailable(retainAvailable)}
        if let maximumPacketSize { self.maximumPacketSize = Property.maximumPacketSize(maximumPacketSize)}
        if let assignedClientIdentifier { self.assignedClientIdentifier = Property.assignedClientIdentifier(assignedClientIdentifier)}
        if let topicAliasMaximum { self.topicAliasMaximum = Property.topicAliasMaximum(topicAliasMaximum)}
        if let reasonString  { self.reasonString = Property.reasonString(reasonString)}
        if let userProperties {
            for (key, value) in userProperties { self.userProperties.append(Property.userProperty(key, value))}
        }
        if let wildcardSubscriptionAvailable { self.wildcardSubscriptionAvailable = Property.wildcardSubscriptionAvailable(wildcardSubscriptionAvailable)}
        if let subscriptionIdentifierAvailable { self.subscriptionIdentifierAvailable = Property.subscriptionIdentifierAvailable(subscriptionIdentifierAvailable)}
        if let sharedSubscriptionAvailable { self.sharedSubscriptionAvailable = Property.sharedSubscriptionAvailable(sharedSubscriptionAvailable)}
        if let serverKeepalive { self.serverKeepalive = Property.serverKeepalive(serverKeepalive)}
        if let responseInformation { self.responseInformation = Property.responseInformation(responseInformation)}
        if let serverReference { self.serverReference = Property.serverReference(serverReference)}
        if let authenticationMethod { self.authenticationMethod = Property.authenticationMethod(authenticationMethod)}
        if let authenticationData { self.authenticationData = Property.authenticationData(authenticationData)}
    }

    public init(from properties: [Property]) throws {
        for property in properties {
            switch property.identifier {
                case .sessionExpiryInterval:
                    try setProperty(&sessionExpiryInterval, property)
                case .receiveMaximum:
                    try setProperty(&receiveMaximum, property)
                case .maximumQoS:
                    try setProperty(&maximumQoS, property)
                case .retainAvailable:
                    try setProperty(&retainAvailable, property)
                case .maximumPacketSize:
                    try setProperty(&maximumPacketSize, property)
                case .assignedClientIdentifier:
                    try setProperty(&assignedClientIdentifier, property)
                case .topicAliasMaximum:
                    try setProperty(&topicAliasMaximum, property)
                case .reasonString:
                    try setProperty(&reasonString, property)
                case .userProperty:
                    self.userProperties.append(property)
                case .wildcardSubscriptionAvailable:
                    try setProperty(&wildcardSubscriptionAvailable, property)
                case .subscriptionIdentifierAvailable:
                    try setProperty(&subscriptionIdentifierAvailable, property)
                case .sharedSubscriptionAvailable:
                    try setProperty(&sharedSubscriptionAvailable, property)
                case .serverKeepalive:
                    try setProperty(&serverKeepalive, property)
                case .responseInformation:
                    try setProperty(&responseInformation, property)
                case .serverReference:
                    try setProperty(&serverReference, property)
                case .authenticationMethod:
                    try setProperty(&authenticationMethod, property)
                case .authenticationData:
                    try setProperty(&authenticationData, property)
                default:
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .incorrectdProperty(inPacket: .CONNACK)))
            }
        }
    }
}

public struct ConnackVariableHeader: Equatable, Sendable {
    let sessionPresent: UInt8
    let connectReturnCode: ConnectReturnCode?
    let connectReasonCode: ConnectReasonCode?
    let connackProperties: ConnackProperties?

    public init(sessionPresent: UInt8, connectReturnCode: ConnectReturnCode? = nil, connectReasonCode: ConnectReasonCode? = nil, connackProperties: ConnackProperties? = nil) {
        self.sessionPresent = sessionPresent
        self.connectReturnCode = connectReturnCode
        self.connectReasonCode = connectReasonCode
        self.connackProperties = connackProperties
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []

        bytes.append(self.sessionPresent)
        if let connectReturnCode = self.connectReturnCode {
            bytes.append(connectReturnCode.rawValue)
        } else if let connectReasonCode = self.connectReasonCode {
            bytes.append(connectReasonCode.rawValue)
            if let properties = self.connackProperties {
                bytes.append(contentsOf: properties.encode())
            }
        }

        return bytes
    }

    public func toString() -> String {
        var str: String = "Session present: \(self.sessionPresent)"
        if let connectReturnCode = self.connectReturnCode {
            str.append(", Connect return code: \(connectReturnCode.toString())")
        } else if let connectReasonCode = self.connectReasonCode {
            str.append(", Connect reason code: \(connectReasonCode)")
            if let properties = self.connackProperties {
                str.append(", Properties: \(properties.toString())")
            }
        }
        return str
    }
}

public struct Connack: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: ConnackVariableHeader

}

// MARK: Init
extension Connack {
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

        let msglen = try decodeRemainigLength(bytes)

        self.fixedHeader = FixedHeader(type: .CONNACK, flags: flags, remainingLength: msglen.value)

        // varheader
        let remaining = Bytes(bytes[msglen.length + 1..<bytes.count])

        if remaining[0] != 0 && remaining[0] != 1 {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .reservedBitModified))
        }

        // v3
        if remaining.count == 2 {
            guard let connectionReturnCode = ConnectReturnCode(rawValue: remaining[1]) else {
                throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidReturnCode))
            }
            self.varHeader = ConnackVariableHeader(
                sessionPresent: remaining[0], connectReturnCode: connectionReturnCode)
        // v5
        } else {
            guard let connectReasonCode = ConnectReasonCode(rawValue: remaining[1]) else {
                throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidReturnCode))
            }

            // Decode properties
            var properties: [Property] = []
            let propslen = try decodeRemainigLength(Bytes(remaining[1..<remaining.count]))
            let props = Bytes(remaining[propslen.length + 2..<remaining.count])
            var buf = ByteBuffer(bytes: props)
            var bytesRead = 0
            while bytesRead < propslen.value {
                guard let idByte: Byte = buf.readInteger(as: Byte.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read byte at index: \(buf.readerIndex), from buffer: \(buf.debugDescription)")))
                }
                bytesRead += 1
                guard let id = PropertyIdentifier(rawValue: idByte) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidPropertyIdentifier))
                }
                let property = try Property.decode(id: id, from: &buf, bytesRead: &bytesRead)
                properties.append(property)
            }

            self.varHeader = try ConnackVariableHeader(
                sessionPresent: remaining[0],
                connectReasonCode: connectReasonCode,
                connackProperties: ConnackProperties.init(from: properties)
            )
        }
    }

    // v3
    public init(returnCode: ConnectReturnCode, sessionPresent: Bool) {
        self.fixedHeader = FixedHeader(type: .CONNACK, flags: 0, remainingLength: 2)
        self.varHeader = ConnackVariableHeader(
            sessionPresent: sessionPresent ? 1 : 0, connectReturnCode: returnCode)
    }

    // v5´
    public init(reasonCode: ConnectReasonCode, sessionPresent: Bool, properties: ConnackProperties) {
        self.varHeader = ConnackVariableHeader(sessionPresent: sessionPresent ? 1 : 0, connectReasonCode: reasonCode, connackProperties: properties)
        self.fixedHeader = FixedHeader(type: .CONNACK, flags: 0, remainingLength: UInt(self.varHeader.encode().count))
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
