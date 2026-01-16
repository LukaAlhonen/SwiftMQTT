struct MQTTPingrespPacket: MQTTControlPacket {
    var fixedHeader: FixedHeader

    init(bytes: ByteBuffer) throws {
        guard let type = MQTTControlPacketType(rawValue: bytes[0] >> 4) else {
            throw MQTTError.DecodePacketError(message: "Invalid packet type: \(bytes[0] >> 4)")
        }

        self.fixedHeader = FixedHeader(type: type, flags: 0, remainingLength: 0)
    }

    func encode() -> ByteBuffer {
        return self.fixedHeader.encode()
    }


    func toString() -> String {
        return self.fixedHeader.toString()
    }
}
