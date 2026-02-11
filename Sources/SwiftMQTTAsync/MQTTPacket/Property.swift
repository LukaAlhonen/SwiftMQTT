public struct Property: Sendable, Equatable {
    public let identifier: PropertyIdentifier
    public let value: PropertyValue

    private init(identifier: PropertyIdentifier, value: PropertyValue) {
        self.identifier = identifier
        self.value = value
    }
}

public extension Property {
    static func payloadFormatIndicator(_ value: Byte) -> Property { return self.init(identifier: .payloadFormatIndicator, value: .byte(value)) }

    static func messageExpiryInterval(_ value: UInt32) -> Property { return self.init(identifier: .messageExpiryInterval, value: .fourByteInt(value)) }

    static func contentType(_ value: String) -> Property { return self.init(identifier: .contentType, value: .utf8String(value)) }

    static func responseTopic(_ value: String) -> Property { return self.init(identifier: .responseTopic, value: .utf8String(value)) }

    static func correlationData(_ value: Bytes) -> Property { return self.init(identifier: .correlationData, value: .binaryData(value)) }

    static func subscriptionIdentifier(_ value: UInt) -> Property { return self.init(identifier: .subscriptionIdentifier, value: .variableByteInt(value)) }

    static func sessionExpiryInterval(_ value: UInt32) -> Property { return self.init(identifier: .sessionExpiryInterval, value: .fourByteInt(value))}

    static func assignedClientIdentifier(_ value: String) -> Property { return self.init(identifier: .assignedClientIdentifier, value: .utf8String(value)) }

    static func serverKeepalive(_ value: UInt16) -> Property { return self.init(identifier: .serverKeepalive, value: .twoByteInt(value)) }

    static func authenticationMethod(_ value: String) -> Property { return self.init(identifier: .authenticationMethod, value: .utf8String(value)) }

    static func authenticationData(_ value: Bytes) -> Property { return self.init(identifier: .authenticationData, value: .binaryData(value)) }

    static func requestProblemInformation(_ value: Byte) -> Property { return self.init(identifier: .requestProblemInformation, value: .byte(value)) }

    static func willDelayInterval(_ value: UInt32) -> Property { return self.init(identifier: .willDelayInterval, value: .fourByteInt(value)) }

    static func requestResponseInformation(_ value: Byte) -> Property { return self.init(identifier: .requestResponseInformation, value: .byte(value)) }

    static func responseInformation(_ value: String) -> Property { return self.init(identifier: .responseInformation, value: .utf8String(value)) }

    static func serverReference(_ value: String) -> Property { return self.init(identifier: .serverReference, value: .utf8String(value)) }

    static func reasonString(_ value: String) -> Property { return self.init(identifier: .reasonString, value: .utf8String(value)) }

    static func receiveMaximum(_ value: UInt16) -> Property { return self.init(identifier: .receiveMaximum, value: .twoByteInt(value)) }

    static func topicAliasMaximum(_ value: UInt16) -> Property { return self.init(identifier: .topicAliasMaximum, value: .twoByteInt(value)) }

    static func topicAlias(_ value: UInt16) -> Property { return self.init(identifier: .topicAlias, value: .twoByteInt(value)) }

    static func maximumQoS(_ value: Byte) -> Property { return self.init(identifier: .maximumQoS, value: .byte(value)) }

    static func retainAvailable(_ value: Byte) -> Property { return self.init(identifier: .retainAvailable, value: .byte(value)) }

    static func userProperty(_ value1: String, _ value2: String) -> Property { return self.init(identifier: .userProperty, value: .utf8StringPair(value1, value2)) }

    static func maximumPacketSize(_ value: UInt32) -> Property { return self.init(identifier: .maximumPacketSize, value: .fourByteInt(value)) }

    static func wildcardSubscriptionAvailable(_ value: Byte) -> Property { return self.init(identifier: .wildcardSubscriptionAvailable, value: .byte(value)) }

    static func subscriptionIdentifierAvailable(_ value: Byte) -> Property { return self.init(identifier: .subscriptionIdentifierAvailable, value: .byte(value)) }

    static func sharedSubscriptionAvailable(_ value: Byte) -> Property { return self.init(identifier: .sharedSubscriptionAvailable, value: .byte(value)) }
}

public extension Property {
    func encode() -> Bytes {
        var bytes: Bytes = [self.identifier.rawValue]
        switch self.value {
            case .byte(let byte):
                bytes.append(byte)
            case .binaryData(var bytes):
                bytes.append(contentsOf: bytes)
            case .utf8String(let string):
                let stringBytes = Bytes(string.utf8)
                bytes.append(contentsOf: encodeUInt16(UInt16(stringBytes.count)))
                bytes.append(contentsOf: stringBytes)
            case .utf8StringPair(let key, let value):
                let keyBytes = Bytes(key.utf8)
                let valueBytes = Bytes(value.utf8)

                bytes.append(contentsOf: encodeUInt16(UInt16(keyBytes.count)))
                bytes.append(contentsOf: keyBytes)

                bytes.append(contentsOf: encodeUInt16(UInt16(valueBytes.count)))
                bytes.append(contentsOf: valueBytes)
            case .variableByteInt(let i):
                bytes.append(contentsOf: encodeUInt(i))
            case .twoByteInt(let i):
                bytes.append(contentsOf: encodeUInt16(i))
            case .fourByteInt(let i):
                var big = i.bigEndian
                let iBytes: Bytes = withUnsafeBytes(of: &big) { Array($0) }
                bytes.append(contentsOf: iBytes)
        }
        return bytes
    }
}

public enum PropertyValue: Sendable, Equatable {
    case byte(Byte)
    case fourByteInt(UInt32)
    case twoByteInt(UInt16)
    case utf8String(String)
    case utf8StringPair(String, String)
    case binaryData(Bytes)
    case variableByteInt(UInt)
}

public enum PropertyIdentifier: Byte, Sendable, Equatable {
    case payloadFormatIndicator = 0x01
    case messageExpiryInterval = 0x02
    case contentType = 0x03
    case responseTopic = 0x08
    case correlationData = 0x09
    case subscriptionIdentifier = 0x0b
    case sessionExpiryInterval = 0x11
    case assignedClientIdentifier = 0x12
    case serverKeepalive = 0x13
    case authenticationMethod = 0x15
    case authenticationData = 0x16
    case requestProblemInformation = 0x17
    case willDelayInterval = 0x18
    case requestResponseInformation = 0x19
    case responseInformation = 0x1a
    case serverReference = 0x1c
    case reasonString = 0x1f
    case receiveMaximum = 0x21
    case topicAliasMaximum = 0x22
    case topicAlias = 0x23
    case maximumQoS = 0x24
    case retainAvailable = 0x25
    case userProperty = 0x26
    case maximumPacketSize = 0x27
    case wildcardSubscriptionAvailable = 0x28
    case subscriptionIdentifierAvailable = 0x29
    case sharedSubscriptionAvailable = 0x2a
}
