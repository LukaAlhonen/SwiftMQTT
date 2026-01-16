class MQTTPacketParser {
    func parsePacket(data: ByteBuffer) throws -> MQTTControlPacket? {
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
        // Publish
        } else if ((data[0] >> 4) == 3) {
            let publish = try MQTTPublishPacket(bytes: data)
            return publish
        } else {
            return nil
        }
    }
}
