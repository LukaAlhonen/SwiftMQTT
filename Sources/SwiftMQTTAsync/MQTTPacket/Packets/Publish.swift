import NIOCore

public struct PublishProperties: Properties {
    public var payloadFormatIndicator: Property?
    public var messageExpiryInterval: Property?
    public var topicAlias: Property?
    public var responseTopic: Property?
    public var correlationData: Property?
    public var userProperties: [Property] = []
    public var subscriptionIdentifier: Property?
    public var contentType: Property?

    internal var properties: [Property?] {
        var p: [Property?] = []

        p.append(payloadFormatIndicator)
        p.append(messageExpiryInterval)
        p.append(topicAlias)
        p.append(responseTopic)
        p.append(correlationData)
        for property in userProperties { p.append(property) }
        p.append(subscriptionIdentifier)
        p.append(contentType)

        return p
    }

    public init(
        payloadFormatIndicator: Byte? = nil,
        messageExpiryInterval: UInt32? = nil,
        topicAlias: UInt16? = nil,
        responseTopic: String? = nil,
        correlationData: Bytes? = nil,
        userProperties: [(String, String)]? = nil,
        subscriptionIdentifier: UInt? = nil,
        contentType: String? = nil,
    ) {
        if let payloadFormatIndicator {
            self.payloadFormatIndicator = Property.payloadFormatIndicator(payloadFormatIndicator)
        }
        if let messageExpiryInterval {
            self.messageExpiryInterval = Property.messageExpiryInterval(messageExpiryInterval)
        }
        if let topicAlias { self.topicAlias = Property.topicAlias(topicAlias) }
        if let responseTopic { self.responseTopic = Property.responseTopic(responseTopic) }
        if let correlationData { self.correlationData = Property.correlationData(correlationData) }
        if let userProperties {
            for (key, value) in userProperties {
                self.userProperties.append(Property.userProperty(key, value))
            }
        }
        if let subscriptionIdentifier {
            self.subscriptionIdentifier = Property.subscriptionIdentifier(subscriptionIdentifier)
        }
        if let contentType { self.contentType = Property.contentType(contentType) }
    }

    public init(from properties: [Property]) throws {
        for property in properties {
            switch property.identifier {
            case .payloadFormatIndicator:
                try self.setProperty(&self.payloadFormatIndicator, property)
            case .messageExpiryInterval:
                try self.setProperty(&self.messageExpiryInterval, property)
            case .topicAlias:
                try self.setProperty(&self.topicAlias, property)
            case .responseTopic:
                try self.setProperty(&self.responseTopic, property)
            case .correlationData:
                try self.setProperty(&self.correlationData, property)
            case .userProperty:
                self.userProperties.append(property)
            case .subscriptionIdentifier:
                try self.setProperty(&self.subscriptionIdentifier, property)
            case .contentType:
                try self.setProperty(&self.contentType, property)
            default:
                throw MQTTError.protocolViolation(
                    .malformedPacket(reason: .incorrectdProperty(inPacket: .PUBLISH)))
            }
        }
    }
}

public struct PublishVarHeader: Equatable, Sendable {
    public let topicName: String
    public let packetId: UInt16?
    public let properties: PublishProperties?

    public init(topicName: Bytes, packetId: UInt16? = nil, properties: PublishProperties? = nil)
        throws
    {
        guard let t = String(bytes: topicName, encoding: .utf8) else {
            throw MQTTError.unexpectedError("Unable to decode topic name")
        }
        self.topicName = t
        self.packetId = packetId
        self.properties = properties
    }

    public init(topicName: String, packetId: UInt16? = nil, properties: PublishProperties? = nil) {
        self.topicName = topicName
        self.packetId = packetId
        self.properties = properties
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []

        let topicNameBytes: Bytes = Bytes(self.topicName.utf8)
        bytes.append(contentsOf: encodeUInt16(UInt16(topicNameBytes.count)))
        bytes.append(contentsOf: topicNameBytes)
        if let packetId { bytes.append(contentsOf: encodeUInt16(packetId)) }
        bytes.append(contentsOf: properties?.encode() ?? [])

        return bytes
    }

    public func toString() -> String {
        var str = "Topic: \(self.topicName)"
        if let packetId = self.packetId {
            str.append(contentsOf: ", Packet ID: \(packetId)")
        }
        if let properties { str.append(", Properties: \(properties.toString())") }

        return str
    }
}

public struct PublishPayload: Equatable, Sendable {
    public let content: Bytes

    public init(content: Bytes) {
        self.content = content
    }

    public func encode() -> Bytes {
        return self.content
    }

    public func toString() -> String {
        guard let str: String = String(bytes: self.content, encoding: .utf8) else {
            let hex = self.content.map { String(format: "%02X", $0) }.joined(separator: ", ")
            return "[\(hex)]"
        }

        return "Payload: \(str)"
    }
}

public struct Publish: MQTTControlPacket, Equatable {
    public var fixedHeader: FixedHeader
    public var variableHeader: PublishVarHeader
    public var payload: PublishPayload

    public let dup: Bool
    public let qos: QoS
    public let retain: Bool

}

extension Publish {
    public init(bytes: Bytes, version: Version) throws {
        let typeBytes = bytes[0] >> 4
        guard let type = MQTTControlPacketType(rawValue: typeBytes) else {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidType(expected: .PUBLISH, actual: typeBytes)))
        }

        let flags = bytes[0] & 0b00001111
        let dup = (flags >> 3) == 1 ? true : false
        guard let qos = QoS(rawValue: ((flags & 0b00000111) >> 1)) else {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidQoS))
        }
        let retain = (flags & 0b00000001) == 1 ? true : false

        self.dup = dup
        self.qos = qos
        self.retain = retain

        let msgLen = try decodeRemainigLength(bytes)

        self.fixedHeader = FixedHeader(type: type, flags: flags, remainingLength: msgLen.value)

        // VarHeader
        let remaining = Bytes(bytes[msgLen.length + 1..<bytes.count])
        let topicLenMSB = remaining[0]
        let topicLenLSB = remaining[1]
        let topicLen = (UInt16(topicLenMSB) << 8) | UInt16(topicLenLSB)
        let topicBytes = Bytes(remaining[2..<2 + Int(topicLen)])
        var packetId: UInt16? = nil
        var propertiesBytes: Bytes = []
        var publishProperties: PublishProperties? = nil

        // PacketId only included if QoS > 0
        if qos.rawValue > 0 {
            let packetIdMSB = remaining[2 + Int(topicLen)]
            let packetIdLSB = remaining[3 + Int(topicLen)]
            packetId = (UInt16(packetIdMSB) << 8) | UInt16(packetIdLSB)
            propertiesBytes = Bytes(remaining[3 + Int(topicLen)..<remaining.count])
        } else {
            propertiesBytes = Bytes(remaining[1 + Int(topicLen)..<remaining.count])
        }
        switch version {
        case .v3:
            self.variableHeader = try PublishVarHeader(topicName: topicBytes, packetId: packetId)
            self.payload = PublishPayload(
                content: Bytes(remaining[self.variableHeader.encode().count..<remaining.count]))
        case .v5:
            // Decode properties
            let propslen = try decodeRemainigLength(
                Bytes(propertiesBytes[0..<propertiesBytes.count]))
            let props = Bytes(propertiesBytes[propslen.length + 1..<2 + Int(propslen.value)])
            let properties = try decodeProperties(from: props, length: propslen.value)
            publishProperties = try .init(from: properties)
        }
        self.variableHeader = try .init(
            topicName: topicBytes, packetId: packetId, properties: publishProperties)
        self.payload = .init(
            content: Bytes(remaining[self.variableHeader.encode().count..<remaining.count]))
    }

    public init(
        topicName: String, message: String, packetId: UInt16? = nil, duplicate: Bool = false,
        qos: QoS, retain: Bool = false, properties: PublishProperties? = nil
    ) throws {
        if qos.rawValue > 0 && packetId == nil {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .missingPacketId))
        }
        self.dup = duplicate
        self.qos = qos
        self.retain = retain

        // construct flags
        let dupFlag: Byte = (self.dup ? 1 : 0) << 3
        let qosFlag: Byte = self.qos.rawValue << 1
        let retainFlag: Byte = self.retain ? 1 : 0

        var flags: Byte = 0
        flags |= dupFlag
        flags |= qosFlag
        flags |= retainFlag

        self.variableHeader = .init(
            topicName: topicName, packetId: packetId, properties: properties)
        self.payload = .init(content: Bytes(message.utf8))
        self.fixedHeader = .init(
            type: .PUBLISH, flags: flags,
            remainingLength: UInt(self.variableHeader.encode().count + self.payload.encode().count))
    }

    public init(
        topicName: String, message: Bytes, packetId: UInt16? = nil, duplicate: Bool = false,
        qos: QoS, retain: Bool = false, properties: PublishProperties? = nil
    ) throws {
        if qos.rawValue > 0 && packetId == nil {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .missingPacketId))
        }
        self.dup = duplicate
        self.qos = qos
        self.retain = retain

        // construct flags
        let dupFlag: Byte = (self.dup ? 1 : 0) << 3
        let qosFlag: Byte = self.qos.rawValue << 1
        let retainFlag: Byte = self.retain ? 1 : 0

        var flags: Byte = 0
        flags |= dupFlag
        flags |= qosFlag
        flags |= retainFlag

        self.variableHeader = .init(
            topicName: topicName, packetId: packetId, properties: properties)
        self.payload = .init(content: message)
        self.fixedHeader = .init(
            type: .PUBLISH, flags: flags,
            remainingLength: UInt(self.variableHeader.encode().count + self.payload.encode().count))
    }
}

extension Publish {
    public func encode() -> Bytes {
        var bytes: Bytes = []
        bytes.append(contentsOf: self.fixedHeader.encode())
        bytes.append(contentsOf: self.variableHeader.encode())
        bytes.append(contentsOf: self.payload.encode())

        return bytes
    }

    public func toString() -> String {
        return
            "\(self.fixedHeader.toString()): dup: \(self.dup), qos: \(self.qos), retain: \(self.retain), \(self.variableHeader.toString()), \(self.payload.toString())"
    }
}
