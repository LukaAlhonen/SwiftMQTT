struct Pingresp: MQTTControlPacket {
    var fixedHeader: FixedHeader

    init(bytes: Bytes) throws {
        guard let type = MQTTControlPacketType(rawValue: bytes[0] >> 4) else {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidType(expected: .PINGRESP, actual: bytes[0] >> 4)))
        }

        self.fixedHeader = FixedHeader(type: type, flags: 0, remainingLength: 0)
    }

    init() {
        self.fixedHeader = FixedHeader(type: .PINGRESP, flags: 0, remainingLength: 0)
    }

    func encode() -> Bytes {
        return self.fixedHeader.encode()
    }


    func toString() -> String {
        return self.fixedHeader.toString()
    }
}
