public struct UnsubscribeProperties: Properties {
    public var userProperties: [Property] = []

    internal var properties: [Property?] {
        var p: [Property] = []
        for property in self.userProperties { p.append(property) }
        return p
    }
}

extension UnsubscribeProperties {
    public init(userProperties: [(String, String)]? = nil) {
        if let userProperties {
            for (key, value) in userProperties {
                self.userProperties.append(Property.userProperty(key, value))
            }
        }
    }

    public init(from properties: [Property]) throws {
        for property in properties {
            if case .userProperty = property.identifier {
                self.userProperties.append(property)
            } else {
                throw MQTTError.protocolViolation(
                    .malformedPacket(reason: .incorrectdProperty(inPacket: .UNSUBSCRIBE)))
            }
        }
    }
}

public struct UnsubscribePayload: Equatable, Sendable {
    public let topics: [String]

    public init(topics: [String]) {
        self.topics = topics
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []

        for topic in self.topics {
            let topicBytes = Bytes(topic.utf8)
            let topicLen = encodeUInt16(UInt16(topicBytes.count))

            bytes.append(contentsOf: topicLen)
            bytes.append(contentsOf: topicBytes)
        }

        return bytes
    }

    public func toString() -> String {
        let topicsString = self.topics.joined(separator: ", ")
        return "Topics: [\(topicsString)]"
    }
}

public struct UnsubscribeVariableHeader: Equatable, Sendable {
    public let packetId: UInt16
    public var properties: UnsubscribeProperties?

    public init(packetId: UInt16, properties: UnsubscribeProperties? = nil) {
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
        if let properties { s.append(properties.toString()) }
        return s
    }
}

public struct Unsubscribe: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: UnsubscribeVariableHeader
    public var payload: UnsubscribePayload

    public init(packetId: UInt16, properties: UnsubscribeProperties? = nil, topics: [String]) {
        self.varHeader = .init(packetId: packetId, properties: properties)
        self.payload = .init(topics: topics)
        self.fixedHeader = .init(
            type: .UNSUBSCRIBE, flags: 2,
            remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []
        bytes.append(contentsOf: self.fixedHeader.encode())
        bytes.append(contentsOf: self.varHeader.encode())
        bytes.append(contentsOf: self.payload.encode())

        return bytes
    }

    public func toString() -> String {
        return
            "\(self.fixedHeader.toString()), \(self.varHeader.toString()), \(self.payload.toString())"
    }
}
