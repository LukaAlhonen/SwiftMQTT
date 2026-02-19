import NIOCore

public enum PubrecReasonCode: Byte, Equatable, Sendable {
    case success = 0x00
    case noMatchingSubscribers = 0x10
    case unspecifiedError = 0x80
    case implementationSpecificError = 0x83
    case notAuthorized = 0x87
    case topicNameInvalid = 0x90
    case packetIdentifierInUse = 0x91
    case quotaExceeded = 0x97
    case payloadFormatInvalid = 0x99
}

extension PubrecReasonCode {
    public func toString() -> String {
        switch self {
        case .success:
            "SUCCESS"
        case .noMatchingSubscribers:
            "NO MATCHING SUBSCRIBERS"
        case .unspecifiedError:
            "UNSPECIFIED ERROR"
        case .implementationSpecificError:
            "IMPLEMENTATION SPECIFIC ERROR"
        case .notAuthorized:
            "NOT AUTHORIZED"
        case .topicNameInvalid:
            "TOPIC NAME INVALID"
        case .packetIdentifierInUse:
            "PACKET IDENTIFIER IN USE"
        case .quotaExceeded:
            "QUOTA EXCEEDED"
        case .payloadFormatInvalid:
            "PAYLOAD FORMAT INVALID"
        }
    }
}

public struct PubrecProperties: Properties {
    public var reasonString: Property?
    public var userProperties: [Property] = []

    internal var properties: [Property?] {
        var p: [Property?] = []
        p.append(self.reasonString)
        for property in self.userProperties { p.append(property) }
        return p
    }
}

extension PubrecProperties {
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
                    .malformedPacket(reason: .incorrectdProperty(inPacket: .PUBREC)))
            }
        }
    }
}

public struct PubrecVariableHeader: Equatable, Sendable {
    public let packetId: UInt16
    public var reasonCode: PubrecReasonCode?
    public var properties: PubrecProperties?

    public init(
        packetId: UInt16, reasonCode: PubrecReasonCode? = nil, properties: PubrecProperties? = nil
    ) {
        self.packetId = packetId
        self.reasonCode = reasonCode
        self.properties = properties
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []
        bytes.append(contentsOf: encodeUInt16(self.packetId))
        if let reasonCode { bytes.append(reasonCode.rawValue) }
        bytes.append(contentsOf: self.properties?.encode() ?? [])
        return bytes
    }

    public func toString() -> String {
        var s: String = ""

        s.append("Packet ID: \(self.packetId)")
        if let reasonCode { s.append("Reason code: \(reasonCode.toString())") }
        if let properties { s.append("Properties: \(properties.toString())") }

        return s
    }
}

public struct Pubrec: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: PubrecVariableHeader
}

extension Pubrec {
    public init(
        packetId: UInt16, reasonCode: PubrecReasonCode? = nil, properties: PubrecProperties? = nil
    ) {
        self.varHeader = .init(packetId: packetId, reasonCode: reasonCode, properties: properties)
        self.fixedHeader = .init(
            type: .PUBREC, flags: 0, remainingLength: UInt(self.varHeader.encode().count))
    }

    public init(bytes: Bytes, version: Version) throws {
        let typeBytes = bytes[0] >> 4
        guard let type = MQTTControlPacketType(rawValue: bytes[0] >> 4) else {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidType(expected: .PUBREC, actual: typeBytes)))
        }

        if type != .PUBREC {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .incorrectType(expected: .PUBCOMP, actual: type)))
        }

        let flags = bytes[0] & 0b00001111
        if flags != 0 {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidFlags(expected: 0, actual: flags)))
        }

        let msgLen = bytes[1]
        let packetIdMSB = bytes[2]
        let packetIdLSB = bytes[3]
        let packetId = (UInt16(packetIdMSB) << 8) | UInt16(packetIdLSB)

        let remaining: Bytes = Bytes(bytes[4..<bytes.count])

        var pubrecReasonCode: PubrecReasonCode? = nil
        var pubrecProperties: PubrecProperties? = nil

        switch version {
        case .v3:
            if remaining.count > 0 {
                throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidRemainingLength))
            }
        case .v5:
            if msgLen > 2 {
                // Decode reason code
                guard let reasonCode: PubrecReasonCode = PubrecReasonCode(rawValue: remaining[0])
                else {
                    throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidReturnCode))
                }
                pubrecReasonCode = reasonCode

                // Decode properties
                var properties: [Property] = []
                let propslen = try decodeRemainigLength(Bytes(remaining[0..<remaining.count]))
                let props = Bytes(remaining[propslen.length + 1..<2 + Int(propslen.value)])
                var buf = ByteBuffer(bytes: props)
                var bytesRead = 0
                while bytesRead < propslen.value {
                    guard let idByte: Byte = buf.readInteger(as: Byte.self) else {
                        throw MQTTError.protocolViolation(
                            .malformedPacket(
                                reason: .decodeError(
                                    "Unable to read byte at index: \(buf.readerIndex), from buffer: \(buf.debugDescription)"
                                )))
                    }
                    bytesRead += 1
                    guard let id = PropertyIdentifier(rawValue: idByte) else {
                        throw MQTTError.protocolViolation(
                            .malformedPacket(reason: .invalidPropertyIdentifier))
                    }
                    let property = try Property.decode(id: id, from: &buf, bytesRead: &bytesRead)
                    properties.append(property)
                }
                pubrecProperties = try .init(from: properties)
            } else {
                pubrecReasonCode = .success
            }
        }

        self.fixedHeader = .init(type: type, flags: flags, remainingLength: UInt(msgLen))
        self.varHeader = .init(
            packetId: packetId, reasonCode: pubrecReasonCode, properties: pubrecProperties)
    }
}

extension Pubrec {
    public func encode() -> Bytes {
        var bytes: Bytes = []

        bytes.append(contentsOf: self.fixedHeader.encode())
        bytes.append(contentsOf: self.varHeader.encode())

        return bytes
    }

    public func toString() -> String {
        return "\(self.fixedHeader.toString()), \(self.varHeader.toString())"
    }
}
