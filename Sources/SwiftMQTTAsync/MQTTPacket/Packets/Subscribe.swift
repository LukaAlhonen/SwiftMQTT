public struct SubscribeProperties: Properties, Hashable {
    public var subscriptionIdentifier: Property?
    public var userProperties: [Property] = []

    internal var properties: [Property?] {
        var p: [Property?] = []
        p.append(self.subscriptionIdentifier)
        for property in self.userProperties {
            p.append(property)
        }

        return p
    }

    public init(subscriptionIdentifier: UInt? = nil, userProperties: [(String, String)]? = nil) {
        if let subscriptionIdentifier {
            self.subscriptionIdentifier = Property.subscriptionIdentifier(subscriptionIdentifier)
        }
        if let userProperties {
            for (key, value) in userProperties {
                self.userProperties.append(Property.userProperty(key, value))
            }
        }
    }

    public init(from properties: [Property]) throws {
        for property in properties {
            switch property.identifier {
            case .subscriptionIdentifier:
                try self.setProperty(&self.subscriptionIdentifier, property)
            case .userProperty:
                self.userProperties.append(property)
            default:
                throw MQTTError.protocolViolation(
                    .malformedPacket(reason: .incorrectdProperty(inPacket: .SUBSCRIBE)))
            }
        }
    }
}

public struct SubscribeVariableHeader: Equatable, Sendable {
    public var packetId: UInt16
    public var properties: SubscribeProperties?

    public init(packetId: UInt16, properties: SubscribeProperties? = nil) {
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
        var s: String = "Packet ID: \(self.packetId)"
        if let properties { s.append("Properties: \(properties.toString())") }
        return s
    }
}

public struct SubscribePayload: Equatable, Sendable {
    public let topics: [TopicFilter]

    public init(topics: [TopicFilter]) {
        self.topics = topics
    }

    public func encode() -> Bytes {
        var data: Bytes = []

        for topicFilter in self.topics {
            data.append(contentsOf: topicFilter.encode())
        }

        return data
    }

    public func toString() -> String {
        let s = self.topics.map { "Topic: \($0.topic), QoS: \($0.qos)" }.joined(separator: ", ")
        return "Topics: [\(s)]"
    }
}

public struct Subscribe: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: SubscribeVariableHeader
    public var payload: SubscribePayload

    public init(packetId: UInt16 = 1, properties: SubscribeProperties? = nil, topics: [TopicFilter])
    {
        self.varHeader = SubscribeVariableHeader(packetId: packetId, properties: properties)
        self.payload = SubscribePayload(topics: topics)
        self.fixedHeader = FixedHeader(
            type: .SUBSCRIBE, flags: 0b0010,
            remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }

    public func encode() -> Bytes {
        var data: Bytes = []
        data.append(contentsOf: fixedHeader.encode())
        data.append(contentsOf: varHeader.encode())
        data.append(contentsOf: payload.encode())

        return data
    }

    public func toString() -> String {
        return
            "\(self.fixedHeader.toString()), \(self.varHeader.toString()), \(self.payload.toString())"
    }
}
