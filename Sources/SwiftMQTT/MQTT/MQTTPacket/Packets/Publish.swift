import Foundation

struct PublishVarHeader: Equatable {
    let topicName: String
    let packetId: UInt16?

    init(topicName: Bytes, packetId: UInt16?) throws {
        guard let t = String(bytes: topicName, encoding: .utf8) else {
            throw MQTTError.DecodePacketError(message: "Unable to decode topic name")
        }
        self.topicName = t
        self.packetId = packetId
    }

    init(topicName: String, packetId: UInt16?) {
        self.topicName = topicName
        self.packetId = packetId
    }

    func encode() -> Bytes {
        var bytes: Bytes = []

        let topicNameBytes: Bytes = Bytes(self.topicName.utf8)
        bytes.append(contentsOf: encodeUInt16(UInt16(topicNameBytes.count)))
        bytes.append(contentsOf: topicNameBytes)
        if let packetId = self.packetId {
            bytes.append(contentsOf: encodeUInt16(packetId))
        }

        return bytes
    }

    func toString() -> String {
        var str = "topicName: \(self.topicName)"
        if let packetId = self.packetId {
            str.append(contentsOf: ", packetId: \(packetId)")
        }

        return str
    }
}

struct PublishPayload: Equatable {
    let content: Bytes

    init(content: Bytes) {
        self.content = content
    }

    func encode() -> Bytes {
        return self.content
    }

    func toString() -> String {
        guard let str: String = String(bytes: self.content, encoding: .utf8) else {
            let hex = self.content.map { String(format: "%02X", $0) }.joined(separator: ", ")
            return "[\(hex)]"
        }

        return str
    }
}

struct Publish: MQTTControlPacket, Equatable {
    var fixedHeader: FixedHeader
    var varHeader: PublishVarHeader
    var payload: PublishPayload

    let dup: Bool
    let qos: QoS
    let retain: Bool

    init(bytes: Bytes) throws {
        guard let type = MQTTControlPacketType(rawValue: bytes[0] >> 4) else {
            throw MQTTError.DecodePacketError(message: "Invalid packet type: \(bytes[0] >> 4)")
        }

        let flags = bytes[0] & 0b00001111
        let dup = (flags >> 3) == 1 ? true : false
        guard let qos = QoS(rawValue: ((flags & 0b00000111) >> 1)) else {
            throw MQTTError.DecodePacketError(message: "Invalid QoS")
        }
        let retain = (flags & 0b00000001) == 1 ? true : false

        self.dup = dup
        self.qos = qos
        self.retain = retain

        let msgLen = try decodeRemainigLength(bytes)

        self.fixedHeader = FixedHeader(type: type, flags: flags, remainingLength: msgLen.value)

        // VarHeader
        let remaining = Bytes(bytes[msgLen.length+1..<bytes.count])
        let topicLenMSB = remaining[0]
        let topicLenLSB = remaining[1]
        let topicLen = (UInt16(topicLenMSB) << 8) | UInt16(topicLenLSB)
        let topicBytes = Bytes(remaining[2..<2+Int(topicLen)])
        // PacketId only included if QoS > 0
        var packetId: UInt16? = nil
        if qos.rawValue > 0 {
            let packetIdMSB = remaining[2+Int(topicLen)]
            let packetIdLSB = remaining[3+Int(topicLen)]
            packetId = (UInt16(packetIdMSB) << 8) | UInt16(packetIdLSB)
        }

        self.varHeader = try PublishVarHeader(topicName: topicBytes, packetId: packetId)
        // Payload
        self.payload = PublishPayload(content: Bytes(remaining[self.varHeader.encode().count..<remaining.count]))
    }

    init(topicName: String, message: String, packetId: UInt16? = nil, duplicate: Bool = false, qos: QoS, retain: Bool = false) {
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

        self.varHeader = .init(topicName: topicName, packetId: packetId)
        self.payload = .init(content: Bytes(message.utf8))
        self.fixedHeader = .init(type: .PUBLISH, flags: flags, remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }

    init(topicName: String, message: Bytes, packetId: UInt16? = nil, duplicate: Bool = false, qos: QoS, retain: Bool = false) {
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

        self.varHeader = .init(topicName: topicName, packetId: packetId)
        self.payload = .init(content: message)
        self.fixedHeader = .init(type: .PUBLISH, flags: flags, remainingLength: UInt(self.varHeader.encode().count + self.payload.encode().count))
    }

    func encode() -> Bytes {
        var bytes: Bytes = []
        bytes.append(contentsOf: self.fixedHeader.encode())
        bytes.append(contentsOf: self.varHeader.encode())
        bytes.append(contentsOf: self.payload.encode())

        return bytes
    }


    func toString() -> String {
        return "\(self.fixedHeader.toString()): dup: \(self.dup), qos: \(self.qos), retain: \(self.retain), \(self.varHeader.toString()), \(self.payload.toString())"
    }
}
