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

struct SubackPayload {
    let returnCodes: [SubackReturnCode]

    init(bytes: ByteBuffer) throws {
        var codes: [SubackReturnCode] = []
        for byte in bytes {
            guard let code = SubackReturnCode(rawValue: byte) else {
                throw MQTTError.DecodePacketError(message: "Invalid return code: \(byte)")
            }
            codes.append(code)
        }
        self.returnCodes = codes
    }

    func encode() -> ByteBuffer {
        var bytes: ByteBuffer = []

        for code in self.returnCodes {
            bytes.append(code.rawValue)
        }

        return bytes
    }

    func toString() -> String {
        return self.returnCodes.map { $0.toString() }.joined(separator: ", ")
    }
}

struct SubackVariableHeader {
    let packetId: UInt16

    init(packetId: UInt16) {
        self.packetId = packetId
    }

    func encode() -> ByteBuffer {
        return encodeUInt16(self.packetId)
    }
}

struct MQTTSubackPacket: MQTTControlPacket {
    var fixedHeader: FixedHeader
    var varHeader: SubackVariableHeader
    var payload: SubackPayload

    init(data: ByteBuffer) throws {
        let packetType = data[0] >> 4
        if (packetType != MQTTControlPacketType.SUBACK.rawValue) {
            throw MQTTError.DecodePacketError(message: "Invalid packet type: \(packetType)")
        }

        // payload len is msglen - 2
        // let msglen = data[1]

        let packetId = (UInt16(data[2]) << 8) | UInt16(data[3])
        self.varHeader = SubackVariableHeader(packetId: packetId)
        self.payload = try SubackPayload(bytes: ByteBuffer(data[4..<data.count]))
        self.fixedHeader = FixedHeader(type: .SUBACK, flags: 0, remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }

    func encode() -> ByteBuffer {
        var bytes: ByteBuffer = []
        bytes.append(contentsOf: self.fixedHeader.encode())
        bytes.append(contentsOf: self.varHeader.encode())
        bytes.append(contentsOf: self.payload.encode())

        return bytes
    }

    func toString() -> String {
        return "Suback, packetId: \(self.varHeader.packetId), \(self.payload.toString())"
    }
}
