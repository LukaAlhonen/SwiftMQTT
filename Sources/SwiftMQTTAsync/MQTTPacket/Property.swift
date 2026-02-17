import NIOCore

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

public func decodeUTF8String(
    from buffer: inout ByteBuffer,
    bytesRead: inout Int
) throws -> String {

    guard let length = buffer.readInteger(endianness: .big, as: UInt16.self) else {
        throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read two byte integer at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
    }

    bytesRead += 2

    guard let data = buffer.readBytes(length: Int(length)) else {
        throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read byte sequence of length: \(length) at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
    }

    bytesRead += Int(length)

    guard let string = String(bytes: data, encoding: .utf8) else {
        throw MQTTError.protocolViolation(.malformedPacket(reason: .malformedUTF8String))
    }

    return string
}

public extension Property {
    static func decode(id: PropertyIdentifier, from buffer: inout ByteBuffer, bytesRead: inout Int) throws -> Property {
        switch id {
            case .payloadFormatIndicator:
                guard let value = buffer.readInteger(as: Byte.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read byte at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 1
                return Property.payloadFormatIndicator(value)
            case .messageExpiryInterval:
                guard let value = buffer.readInteger(endianness: .big, as: UInt32.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read four byte integer at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 4
                return Property.messageExpiryInterval(value)
            case .contentType:
                let value = try decodeUTF8String(from: &buffer, bytesRead: &bytesRead)
                return Property.contentType(value)
            case .responseTopic:
                let value = try decodeUTF8String(from: &buffer, bytesRead: &bytesRead)
                return Property.responseTopic(value)
            case .correlationData:
                guard let length = buffer.readInteger(endianness: .big, as: UInt16.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read two byte integer at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 2
                guard let data = buffer.readBytes(length: Int(length)) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read byte sequence of length: \(length) at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += Int(length)
                return Property.correlationData(data)
            case .subscriptionIdentifier:
                let value = try decodeUInt(from: &buffer, bytesRead: &bytesRead)
                return Property.subscriptionIdentifier(value)
            case .sessionExpiryInterval:
                guard let value = buffer.readInteger(endianness: .big, as: UInt32.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read four byte integer at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 4
                return Property.sessionExpiryInterval(value)
            case .assignedClientIdentifier:
                let value = try decodeUTF8String(from: &buffer, bytesRead: &bytesRead)
                return Property.assignedClientIdentifier(value)
            case .serverKeepalive:
                guard let value = buffer.readInteger(endianness: .big, as: UInt16.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read two byte integer at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 2
                return Property.serverKeepalive(value)
            case .authenticationMethod:
                let value = try decodeUTF8String(from: &buffer, bytesRead: &bytesRead)
                return Property.authenticationMethod(value)
            case .authenticationData:
                guard let length = buffer.readInteger(endianness: .big, as: UInt16.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read two byte integer at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 2
                guard let value = buffer.readBytes(length: Int(length)) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read byte sequence of length: \(length) at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += Int(length)

                return Property.authenticationData(value)
            case .requestProblemInformation:
                guard let value = buffer.readInteger(as: Byte.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read byte at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 1
                return Property.requestProblemInformation(value)
            case .willDelayInterval:
                guard let value = buffer.readInteger(endianness: .big, as: UInt32.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read four byte integer at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 4
                return Property.willDelayInterval(value)
            case .requestResponseInformation:
                guard let value = buffer.readInteger(as: Byte.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read byte at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 1
                return Property.requestResponseInformation(value)
            case .responseInformation:
                let value = try decodeUTF8String(from: &buffer, bytesRead: &bytesRead)
                return Property.responseInformation(value)
            case .serverReference:
                let value = try decodeUTF8String(from: &buffer, bytesRead: &bytesRead)
                return Property.serverReference(value)
            case .reasonString:
                let value = try decodeUTF8String(from: &buffer, bytesRead: &bytesRead)
                return Property.reasonString(value)
            case .receiveMaximum:
                guard let value = buffer.readInteger(endianness: .big, as: UInt16.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read two byte integer at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 2
                return receiveMaximum(value)
            case .topicAliasMaximum:
                guard let value = buffer.readInteger(endianness: .big, as: UInt16.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read two byte integer at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 2
                return Property.topicAliasMaximum(value)
            case .topicAlias:
                guard let value = buffer.readInteger(endianness: .big, as: UInt16.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read two byte integer at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 2
                return Property.topicAlias(value)
            case .maximumQoS:
                guard let value = buffer.readInteger(as: Byte.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read byte at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 1
                return Property.maximumQoS(value)
            case .retainAvailable:
                guard let value = buffer.readInteger(as: Byte.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read byte at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 1
                return Property.retainAvailable(value)
            case .userProperty:
                let key = try decodeUTF8String(from: &buffer, bytesRead: &bytesRead)
                let value = try decodeUTF8String(from: &buffer, bytesRead: &bytesRead)
                return Property.userProperty(key, value)
            case .maximumPacketSize:
                guard let value = buffer.readInteger(endianness: .big, as: UInt32.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read four byte integer at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 4
                return Property.maximumPacketSize(value)
            case .wildcardSubscriptionAvailable:
                guard let value = buffer.readInteger(as: Byte.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read byte at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 1
                return Property.wildcardSubscriptionAvailable(value)
            case .subscriptionIdentifierAvailable:
                guard let value = buffer.readInteger(as: Byte.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read byte at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 1
                return Property.subscriptionIdentifierAvailable(value)
            case .sharedSubscriptionAvailable:
                guard let value = buffer.readInteger(as: Byte.self) else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .decodeError("Unable to read byte at index: \(buffer.readerIndex), from buffer: \(buffer.debugDescription)")))
                }
                bytesRead += 1
                return Property.sharedSubscriptionAvailable(value)
        }
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
