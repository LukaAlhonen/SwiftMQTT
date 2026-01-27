class MQTTPacketParser {
    func parsePacket(data: ByteBuffer) throws -> (any MQTTControlPacket)? {
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
        // Pubrel
        } else if (data.starts(with: [0x62])){
            let pubrel = try MQTTPubrelPacket(bytes: data)
            return pubrel
        // Puback
        } else if (data.starts(with: [0x40])) {
            let puback = try MQTTPubackPacket(bytes: data)
            return puback
        // Pubcomp
        } else if (data.starts(with: [0x70])) {
            let pubcomp = try MQTTPubcompPacket(bytes: data)
            return pubcomp
        // Pubrec
        } else if (data.starts(with: [0x50])) {
            let pubrec = try MQTTPubrecPacket(bytes: data)
            return pubrec
        } else {
            return nil
        }
    }
}
