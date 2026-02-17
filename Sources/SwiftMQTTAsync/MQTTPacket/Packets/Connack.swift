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
        return ""
    }
}

public struct ConnackProperties: Sendable, Equatable {
    public var sessionExpiryInterval: Property? = nil
    public var receiveMaximum: Property? = nil
    public var maximumQoS: Property? = nil
    public var retainAvailable: Property? = nil
    public var maximumPacketSize: Property? = nil
    public var assignedClientIdentifier: Property? = nil
    public var topicAliasMaximum: Property? = nil
    public var reasonString: Property? = nil
    public var userProperty: Property? = nil // TODO: turn into array since this prop can appear multiple times
    public var wildcardSubscriptionAvailable: Property? = nil
    public var subscriptionIdentifierAvailable: Property? = nil
    public var sharedSubscriptionAvailable: Property? = nil
    public var serverKeepalive: Property? = nil
    public var responseInformation: Property? = nil
    public var serverReference: Property? = nil
    public var authenticationMethod: Property? = nil
    public var authenticationData: Property? = nil

    public init(
        sessionExpiryInterval: UInt32? = nil,
        receiveMaximum: UInt16? = nil,
        maximumQoS: Byte? = nil,
        retainAvailable: Byte? = nil,
        maximumPacketSize: UInt32? = nil,
        assignedClientIdentifier: String? = nil,
        topicAliasMaximum: UInt16? = nil,
        reasonString: String? = nil,
        userProperty: (String, String)? = nil, // TODO: turn into array since this prop can appear multiple times
        wildcardSubscriptionAvailable: Byte? = nil,
        subscriptionIdentifierAvailable: Byte? = nil,
        sharedSubscriptionAvailable: Byte? = nil,
        serverKeepalive: UInt16? = nil,
        responseInformation: String? = nil,
        serverReference: String? = nil,
        authenticationMethod: String? = nil,
        authenticationData: Bytes? = nil
    ) {
        if let val = sessionExpiryInterval { self.sessionExpiryInterval = Property.sessionExpiryInterval(val)}
        if let val = receiveMaximum { self.receiveMaximum = Property.receiveMaximum(val)}
        if let val = maximumQoS { self.maximumQoS = Property.maximumQoS(val)}
        if let val = retainAvailable { self.retainAvailable = Property.retainAvailable(val)}
        if let val = maximumPacketSize { self.maximumPacketSize = Property.maximumPacketSize(val)}
        if let val = assignedClientIdentifier { self.assignedClientIdentifier = Property.assignedClientIdentifier(val)}
        if let val = topicAliasMaximum { self.topicAliasMaximum = Property.topicAliasMaximum(val)}
        if let val = reasonString  { self.reasonString = Property.reasonString(val)}
        if let val = userProperty { self.userProperty = Property.userProperty(val.0, val.1)}
        if let val = wildcardSubscriptionAvailable { self.wildcardSubscriptionAvailable = Property.wildcardSubscriptionAvailable(val)}
        if let val = subscriptionIdentifierAvailable { self.subscriptionIdentifierAvailable = Property.subscriptionIdentifierAvailable(val)}
        if let val = sharedSubscriptionAvailable { self.sharedSubscriptionAvailable = Property.sharedSubscriptionAvailable(val)}
        if let val = serverKeepalive { self.serverKeepalive = Property.serverKeepalive(val)}
        if let val = responseInformation { self.responseInformation = Property.responseInformation(val)}
        if let val = serverReference { self.serverReference = Property.serverReference(val)}
        if let val = authenticationMethod { self.authenticationMethod = Property.authenticationMethod(val)}
        if let val = authenticationData { self.authenticationData = Property.authenticationData(val)}
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
                    try setProperty(&userProperty, property)
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

    private func setProperty(_ field: inout Property?, _ value: Property) throws {
        if field != nil {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .duplicateProperty))
        }
        field = value
    }

    public func encode() -> Bytes {
        var pBytes: Bytes = []
        var bytes: Bytes = []
        pBytes.append(contentsOf: self.sessionExpiryInterval?.encode() ?? [])
        pBytes.append(contentsOf: self.receiveMaximum?.encode() ?? [])
        pBytes.append(contentsOf: self.maximumQoS?.encode() ?? [])
        pBytes.append(contentsOf: self.retainAvailable?.encode() ?? [])
        pBytes.append(contentsOf: self.maximumPacketSize?.encode() ?? [])
        pBytes.append(contentsOf: self.assignedClientIdentifier?.encode() ?? [])
        pBytes.append(contentsOf: self.topicAliasMaximum?.encode() ?? [])
        pBytes.append(contentsOf: self.reasonString?.encode() ?? [])
        pBytes.append(contentsOf: self.userProperty?.encode() ?? [])
        pBytes.append(contentsOf: self.wildcardSubscriptionAvailable?.encode() ?? [])
        pBytes.append(contentsOf: self.subscriptionIdentifierAvailable?.encode() ?? [])
        pBytes.append(contentsOf: self.sharedSubscriptionAvailable?.encode() ?? [])
        pBytes.append(contentsOf: self.serverKeepalive?.encode() ?? [])
        pBytes.append(contentsOf: self.responseInformation?.encode() ?? [])
        pBytes.append(contentsOf: self.serverReference?.encode() ?? [])
        pBytes.append(contentsOf: self.authenticationMethod?.encode() ?? [])
        pBytes.append(contentsOf: self.authenticationData?.encode() ?? [])
        bytes.append(contentsOf: encodeUInt(UInt(pBytes.count)))
        bytes.append(contentsOf: pBytes)

        return bytes
    }

    public func toString() -> String {
        var pString: [String] = []

        if let sessionExpiryInterval = self.sessionExpiryInterval { pString.append("sessionExpiryInterval: \(sessionExpiryInterval)")}
        if let receiveMaximum = self.receiveMaximum { pString.append("receiveMaximum: \(receiveMaximum))")}
        if let maximumQoS = self.maximumQoS { pString.append("maximumQoS: \(maximumQoS)")}
        if let retainAvailable = self.retainAvailable { pString.append("retainAvailable: \(retainAvailable)")}
        if let maximumPacketSize = self.maximumPacketSize { pString.append("maximumPacketSize: \(maximumPacketSize)")}
        if let assignedClientIdentifier = self.assignedClientIdentifier { pString.append("assignedClientIdentifier: \(assignedClientIdentifier)")}
        if let topicAliasMaximum = self.topicAliasMaximum { pString.append("topicAliasMaximum: \(topicAliasMaximum)")}
        if let reasonString = self.reasonString { pString.append("reasonString: \(reasonString)")}
        if let userProperty = self.userProperty { pString.append("userProperty: \(userProperty)")}
        if let wildcardSubscriptionAvailable = self.wildcardSubscriptionAvailable { pString.append("wildcardSubscriptionAvailable: \(wildcardSubscriptionAvailable)")}
        if let subscriptionIdentifierAvailable = self.subscriptionIdentifierAvailable { pString.append("subscriptionIdentifierAvailable: \(subscriptionIdentifierAvailable)")}
        if let sharedSubscriptionAvailable = self.sharedSubscriptionAvailable { pString.append("sharedSubscriptionAvailable: \(sharedSubscriptionAvailable)")}
        if let serverKeepalive = self.serverKeepalive { pString.append("serverKeepalive: \(serverKeepalive)")}
        if let responseInformation = self.responseInformation { pString.append("responseInformation: \(responseInformation)")}
        if let serverReference = self.serverReference { pString.append("serverReference: \(serverReference)")}
        if let authenticationMethod = self.authenticationMethod { pString.append("authenticationMethod: \(authenticationMethod)")}
        if let authenticationData = self.authenticationData { pString.append("authenticationData: \(authenticationData)")}

        return pString.joined(separator: ", ")
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
