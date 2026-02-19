import NIOCore

public struct SubackProperties: Properties {
    public var reasonString: Property?
    public var userProperties: [Property] = []

    internal var properties: [Property?] {
        var p: [Property?] = []
        p.append(self.reasonString)
        for property in self.userProperties {
            p.append(property)
        }

        return p
    }
}

extension SubackProperties {
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
                    .malformedPacket(reason: .incorrectdProperty(inPacket: .PUBREL)))
            }
        }
    }
}

public enum SubackReturnCode: UInt8, Sendable {
    case QoS0 = 0x00
    case QoS1 = 0x01
    case QoS2 = 0x02
    case Rejected = 0x80

    public func toString() -> String {
        switch self {
        case .QoS0:
            return "QoS 0"
        case .QoS1:
            return "QoS 1"
        case .QoS2:
            return "QoS 2"
        case .Rejected:
            return "Rejected"
        }
    }
}

public struct SubackPayload: Equatable, Sendable {
    public let returnCodes: [SubackReturnCode]

    public init(bytes: Bytes) throws {
        var codes: [SubackReturnCode] = []
        for byte in bytes {
            guard let code = SubackReturnCode(rawValue: byte) else {
                throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidReturnCode))
            }
            codes.append(code)
        }
        self.returnCodes = codes
    }

    public init(returnCodes: [SubackReturnCode]) {
        self.returnCodes = returnCodes
    }

    public func encode() -> Bytes {
        var bytes: Bytes = []

        for code in self.returnCodes {
            bytes.append(code.rawValue)
        }

        return bytes
    }

    public func toString() -> String {
        let codeString = self.returnCodes.map { $0.toString() }.joined(separator: ", ")
        return "Return codes: [\(codeString)]"
    }
}

public struct SubackVariableHeader: Equatable, Sendable {
    public let packetId: UInt16
    public var properties: SubackProperties?

    public init(packetId: UInt16, properties: SubackProperties? = nil) {
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

public struct Suback: MQTTControlPacket {
    public var fixedHeader: FixedHeader
    public var varHeader: SubackVariableHeader
    public var payload: SubackPayload
}

extension Suback {
    public init(bytes: Bytes, version: Version) throws {
        let typeBytes = bytes[0] >> 4
        guard let type = MQTTControlPacketType(rawValue: typeBytes) else {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidType(expected: .SUBACK, actual: typeBytes)))
        }

        if type != .SUBACK {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .incorrectType(expected: .SUBACK, actual: type)))
        }

        let flags = bytes[0] & 0b00001111
        if flags != 0 {
            throw MQTTError.protocolViolation(
                .malformedPacket(reason: .invalidFlags(expected: 0, actual: flags)))
        }

        let msgLen = try decodeRemainigLength(bytes)

        let remaining = Bytes(bytes[msgLen.length + 1..<bytes.count])
        // let varHeaderBytes: Bytes = Bytes(bytes[2..<bytes.count])
        let packetId = (UInt16(bytes[2]) << 8) | UInt16(bytes[3])
        var subackProperties: SubackProperties? = nil

        if case .v5 = version {
            let varHeaderBytes: Bytes = Bytes(bytes[3..<bytes.count])
            // Decode properties
            let propslen = try decodeRemainigLength(varHeaderBytes)
            let props = Bytes(varHeaderBytes[propslen.length + 1..<2 + Int(propslen.value)])
            let properties = try decodeProperties(from: props, length: propslen.value)
            subackProperties = try .init(from: properties)
        }

        self.fixedHeader = FixedHeader(
            type: type, flags: flags,
            remainingLength: msgLen.value)
        self.varHeader = SubackVariableHeader(packetId: packetId, properties: subackProperties)
        self.payload = try SubackPayload(
            bytes: Bytes(remaining[self.varHeader.encode().count..<remaining.count]))
    }

    public init(
        packetId: UInt16, properties: SubackProperties? = nil, returnCodes: [SubackReturnCode]
    ) {
        self.varHeader = SubackVariableHeader(packetId: packetId, properties: properties)
        self.payload = SubackPayload(returnCodes: returnCodes)
        self.fixedHeader = FixedHeader(
            type: .SUBACK, flags: 0,
            remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }
}

extension Suback {
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
