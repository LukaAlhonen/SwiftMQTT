import Foundation

public struct ConnectProperties: Properties {
    public var sessionExpiryInterval: Property?
    public var receiveMaximum: Property?
    public var maximumPacketSize: Property?
    public var topicAliasMaximum: Property?
    public var requestResponseInformation: Property?
    public var requestProblemInformation: Property?
    public var userProperties: [Property] = []
    public var authenticationMethod: Property?
    public var authenticationData: Property?

    internal var properties: [Property?] {
        var p: [Property?] = []

        p.append(sessionExpiryInterval)
        p.append(receiveMaximum)
        p.append(maximumPacketSize)
        p.append(topicAliasMaximum)
        p.append(requestResponseInformation)
        p.append(requestProblemInformation)
        for property in userProperties {p.append(property)}
        p.append(authenticationMethod)
        p.append(authenticationData)

        return p
    }

    public init(
        sessionExpiryInterval: UInt32? = nil,
        receiveMaximum: UInt16? = nil,
        maximumPacketSize: UInt32? = nil,
        topicAliasMaximum: UInt16? = nil,
        requestResponseInformation: Byte? = nil,
        requestProblemInformation: Byte? = nil,
        userProperties: [(String, String)]? = nil,
        authenticationMethod: String? = nil,
        authenticationData: Bytes? = nil
    ) {
        if let sessionExpiryInterval { self.sessionExpiryInterval = Property.sessionExpiryInterval(sessionExpiryInterval) }
        if let receiveMaximum {self.receiveMaximum = Property.receiveMaximum(receiveMaximum)}
        if let maximumPacketSize {self.maximumPacketSize = Property.maximumPacketSize(maximumPacketSize)}
        if let topicAliasMaximum {self.topicAliasMaximum = Property.topicAliasMaximum(topicAliasMaximum)}
        if let requestResponseInformation {self.requestResponseInformation = Property.requestResponseInformation(requestResponseInformation)}
        if let requestProblemInformation {self.requestProblemInformation = Property.requestProblemInformation(requestProblemInformation)}
        if let userProperties {
            for (key, value) in userProperties { self.userProperties.append(Property.userProperty(key, value))}
        }
        if let authenticationMethod {self.authenticationMethod = Property.authenticationMethod(authenticationMethod)}
        if let authenticationData {self.authenticationData = Property.authenticationData(authenticationData)}
    }

    public init(from properties: [Property]) throws {
        for property in properties {
            switch property.identifier {
                case .sessionExpiryInterval:
                    try self.setProperty(&self.sessionExpiryInterval, property)
                case .receiveMaximum:
                    try self.setProperty(&self.receiveMaximum, property)
                case .maximumPacketSize:
                    try self.setProperty(&self.maximumPacketSize, property)
                case .topicAliasMaximum:
                    try self.setProperty(&self.topicAliasMaximum, property)
                case .requestResponseInformation:
                    try self.setProperty(&self.requestResponseInformation, property)
                case .requestProblemInformation:
                    try self.setProperty(&self.requestProblemInformation, property)
                case .userProperty:
                    self.userProperties.append(property)
                case.authenticationMethod:
                    try self.setProperty(&self.authenticationMethod, property)
                case .authenticationData:
                    try self.setProperty(&self.authenticationData, property)
                default:
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .incorrectdProperty(inPacket: .CONNACK)))
            }
        }
    }
}

public struct WillProperties: Properties {
    public var willDelayInterval: Property? = nil
    public var payloadFormatIndicator: Property? = nil
    public var messageExpiryInterval: Property? = nil
    public var contentType: Property? = nil
    public var responseTopic: Property? = nil
    public var correlationData: Property? = nil
    public var userProperties: [Property] = []

    internal var properties: [Property?] {
        var p: [Property?] = []

        p.append(willDelayInterval)
        p.append(payloadFormatIndicator)
        p.append(messageExpiryInterval)
        p.append(contentType)
        p.append(responseTopic)
        p.append(correlationData)
        for property in userProperties {p.append(property)}

        return p
    }

    public init(
        willDelayInterval: UInt32? = nil,
        payloadFormatIndicator: Byte? = nil,
        messageExpiryInterval: UInt32? = nil,
        contentType: String? = nil,
        responseTopic: String? = nil,
        correlationData: Bytes? = nil,
        userProperties: [(String, String)]? = nil
    ) {
        if let willDelayInterval { self.willDelayInterval = Property.willDelayInterval(willDelayInterval) }
        if let payloadFormatIndicator { self.payloadFormatIndicator = Property.payloadFormatIndicator(payloadFormatIndicator)}
        if let messageExpiryInterval { self.messageExpiryInterval = Property.messageExpiryInterval(messageExpiryInterval)}
        if let contentType { self.contentType = Property.contentType(contentType)}
        if let responseTopic { self.responseTopic = Property.responseTopic(responseTopic) }
        if let correlationData { self.correlationData = Property.correlationData(correlationData) }
        if let userProperties {
            for (key, value) in userProperties {self.userProperties.append(Property.userProperty(key, value))}
        }
    }

    public init(from properties: [Property]) throws {
        for property in properties {
            switch property.identifier {
                case .willDelayInterval:
                    try self.setProperty(&self.willDelayInterval, property)
                case .payloadFormatIndicator:
                    try self.setProperty(&self.payloadFormatIndicator, property)
                case .messageExpiryInterval:
                    try self.setProperty(&self.messageExpiryInterval, property)
                case .contentType:
                    try self.setProperty(&self.contentType, property)
                case .responseTopic:
                    try self.setProperty(&self.responseTopic, property)
                case .correlationData:
                    try self.setProperty(&self.correlationData, property)
                case .userProperty:
                    self.userProperties.append(property)
                default:
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .incorrectdProperty(inPacket: .CONNECT)))
            }
        }
    }
}

public struct ConnConnectFlags: Equatable, Sendable {
    let username: Bool
    let password: Bool
    let willRetain: Bool
    let qos: QoS
    let willFlag: Bool
    let cleanSession: Bool

    public init(
        auth: Auth? = nil,
        cleanSession: Bool = true,
        lwt: LWT? = nil
    ) {
        self.cleanSession = cleanSession
        if let lwt = lwt {
            self.willFlag = true
            self.willRetain = lwt.retain
            self.qos = lwt.qos
        } else {
            self.willFlag = false
            self.willRetain = false
            self.qos = .AtMostOnce
        }
        if let auth = auth {
            self.username = true
            self.password = auth.password != nil ? true : false
        } else {
            self.username = false
            self.password = false
        }
    }

    public func encode() -> UInt8 {
        var flags: UInt8 = 0

        if self.username {
            flags |= 1 << 7
        }

        if self.password {
            flags |= 1 << 6
        }

        if self.willRetain {
            flags |= 1 << 5
        }

        flags |= (qos.rawValue & 0b11) << 3

        if self.willFlag {
            flags |= 1 << 2
        }

        if self.cleanSession {
            flags |= 1 << 1
        }

        return flags
    }

    public func toString() -> String {
        return
            "Username flag: \(self.username), Password flag: \(self.password), WillRetain: \(self.willRetain), Will QoS: \(self.qos), Will flag: \(self.willFlag), Clean session: \(self.cleanSession)"
    }
}

public struct ConnVariableHeader: Equatable, Sendable {
    let protocolName: String
    let protocolLevel: Version
    let connectFlags: ConnConnectFlags
    let keepAlive: UInt16
    let properties: ConnectProperties?

    public init(
        protocolName: String = "MQTT", protocolLevel: Version, connectFlags: ConnConnectFlags,
        keepAlive: UInt16, properties: ConnectProperties? = nil
    ) {
        self.protocolName = protocolName
        self.protocolLevel = protocolLevel
        self.connectFlags = connectFlags
        self.keepAlive = keepAlive
        self.properties = properties
    }

    public func encode() -> Bytes {
        var data: Bytes = []

        data.append(contentsOf: encodeUInt16(UInt16(self.protocolName.count)))
        data.append(contentsOf: self.protocolName.utf8)
        data.append(self.protocolLevel.rawValue)
        data.append(self.connectFlags.encode())
        data.append(contentsOf: encodeUInt16(self.keepAlive))
        if let properties = self.properties { data.append(contentsOf: properties.encode())}

        return data
    }

    public func toString() -> String {
        return
            "Protocol name: \(self.protocolName), Protocol level: \(self.protocolLevel), Connect flags: \(self.connectFlags.toString()), Keepalive: \(self.keepAlive), Properties: \(self.properties?.toString() ?? "[]")"
    }
}

public struct ConnPayload: Equatable, Sendable {
    public let clientId: String
    public var willProperties: WillProperties?
    public var willTopic: String?
    public var willMessage: Data?
    public var username: String?
    public var password: Data?

    public init(clientId: String, lwt: LWT? = nil, auth: Auth? = nil, willProperties: WillProperties? = nil) {
        self.clientId = clientId
        if let lwt = lwt {
            self.willTopic = lwt.topic
            self.willMessage = lwt.message
        }
        if let auth = auth {
            self.username = auth.username
            self.password = auth.password
        }
        self.willProperties = willProperties
    }

    public func encode() -> Bytes {
        var data: Bytes = []

        data.append(contentsOf: encodeUInt16(UInt16(self.clientId.count)))
        data.append(contentsOf: self.clientId.utf8)

        if let willProperties = self.willProperties {
            data.append(contentsOf: willProperties.encode())
        }

        if let willTopic = self.willTopic {
            data.append(contentsOf: encodeUInt16(UInt16(willTopic.count)))
            data.append(contentsOf: willTopic.utf8)
        }

        if let willMessage = self.willMessage {
            data.append(contentsOf: encodeUInt16(UInt16(willMessage.count)))
            data.append(contentsOf: willMessage)
        }

        if let username = self.username {
            data.append(contentsOf: encodeUInt16(UInt16(username.count)))
            data.append(contentsOf: username.utf8)
        }

        if let password = self.password {
            data.append(contentsOf: encodeUInt16(UInt16(password.count)))
            data.append(contentsOf: password)
        }

        return data
    }

    public func toString() -> String {
        let topicString = self.willTopic ?? ""
        let messageString = self.willMessage?.base64EncodedString() ?? ""
        return
            "ClientId: \(self.clientId), Will topic: \(topicString), Will message: \(messageString)"
    }
}

public struct Connect: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: ConnVariableHeader
    public var payload: ConnPayload

    public init(
        version: Version,
        clientId: String,
        keepAlive: UInt16,
        lwt: LWT? = nil,
        auth: Auth? = nil,
        cleanSession: Bool = true,
        properties: ConnectProperties? = nil,
        willProperties: WillProperties? = nil
    ) {
        self.varHeader = ConnVariableHeader(
            protocolName: "MQTT",
            protocolLevel: version,
            connectFlags: ConnConnectFlags(
                auth: auth,
                cleanSession: cleanSession,
                lwt: lwt
            ),
            keepAlive: 60,
            properties: properties
        )

        self.payload = ConnPayload(clientId: clientId, lwt: lwt, auth: auth, willProperties: willProperties)
        self.fixedHeader = FixedHeader(
            type: .CONNECT,
            flags: 0,
            remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }

    public func encode() -> Bytes {
        var data: Bytes = []
        data.append(contentsOf: self.fixedHeader.encode())
        data.append(contentsOf: self.varHeader.encode())
        data.append(contentsOf: self.payload.encode())
        return data
    }

    public func toString() -> String {
        return
            "\(self.fixedHeader.toString()), \(self.varHeader.toString()), \(self.payload.toString())"
    }
}
