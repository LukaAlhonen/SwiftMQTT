enum SubackReturnCode: UInt8 {
    case QoS0 = 0x00
    case QoS1 = 0x01
    case QoS2 = 0x02
    case Rejected = 0x80

    func toString() -> String {
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

struct SubackPayload: Equatable {
    let returnCodes: [SubackReturnCode]

    init(bytes: Bytes) throws {
        var codes: [SubackReturnCode] = []
        for byte in bytes {
            guard let code = SubackReturnCode(rawValue: byte) else {
                throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidReturnCode))
            }
            codes.append(code)
        }
        self.returnCodes = codes
    }

    func encode() -> Bytes {
        var bytes: Bytes = []

        for code in self.returnCodes {
            bytes.append(code.rawValue)
        }

        return bytes
    }

    func toString() -> String {
        return self.returnCodes.map { $0.toString() }.joined(separator: ", ")
    }
}

struct SubackVariableHeader: Equatable {
    let packetId: UInt16

    init(packetId: UInt16) {
        self.packetId = packetId
    }

    func encode() -> Bytes {
        return encodeUInt16(self.packetId)
    }
}

struct Suback: MQTTControlPacket {
    var fixedHeader: FixedHeader
    var varHeader: SubackVariableHeader
    var payload: SubackPayload

    init(bytes: Bytes) throws {
        let typeBytes = bytes[0] >> 4
        guard let type = MQTTControlPacketType(rawValue: typeBytes) else {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidType(expected: .SUBACK, actual: typeBytes)))
        }

        if type != .SUBACK {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .incorrectType(expected: .SUBACK, actual: type)))
        }

        let packetId = (UInt16(bytes[2]) << 8) | UInt16(bytes[3])
        self.varHeader = SubackVariableHeader(packetId: packetId)
        self.payload = try SubackPayload(bytes: Bytes(bytes[4..<bytes.count]))
        self.fixedHeader = FixedHeader(type: type, flags: 0, remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }

    func encode() -> Bytes {
        var bytes: Bytes = []
        bytes.append(contentsOf: self.fixedHeader.encode())
        bytes.append(contentsOf: self.varHeader.encode())
        bytes.append(contentsOf: self.payload.encode())

        return bytes
    }

    func toString() -> String {
        return "Suback, packetId: \(self.varHeader.packetId), \(self.payload.toString())"
    }
}
