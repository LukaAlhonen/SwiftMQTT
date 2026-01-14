class MQTTPacketParser {
    func parsePacket(data: [UInt8]) throws -> MQTTControlPacket? {
        // Connack
        if (data.starts(with: [0x20])) {
            let connack = try MQTTConnackPacket(data: data)
            return connack
        // Suback
        } else if (data.starts(with: [0x90])) {
            let suback = try MQTTSubackPacket(data: data)
            return suback
        // Pingresp
        } else if (data.starts(with: [0xd0])) {
            let pingresp = try MQTTPingrespPacket(bytes: data)
            return pingresp
        } else {
            return nil
        }
    }
}
