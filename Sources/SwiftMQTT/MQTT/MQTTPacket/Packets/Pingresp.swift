struct MQTTPingrespPacket: MQTTControlPacket {
    var fixedHeader: FixedHeader

    init(bytes: [UInt8]) throws {
        guard let type = MQTTControlPacketType(rawValue: bytes[0] >> 4) else {
            throw MQTTError.DecodePacketError(message: "Invalid packet type: \(bytes[0])")
        }

        self.fixedHeader = FixedHeader(type: type, flags: 0, remainingLength: 0)
    }

    func encode() -> [UInt8] {
        return self.fixedHeader.encode()
    }


    func toString() -> String {
        return "PINGRESP"
    }
}
