import NIOCore
import NIOPosix

struct PacketParser {
    private var buffer: ByteBuffer

    init() {
        self.buffer = .init()
    }

    mutating func parsePacket() -> (MQTTPacket)? {
        guard self.buffer.readableBytes >= 2 else {
            return nil
        }

        // guard let fixedHeader = buffer.getBytes(at: 0, length: 1) else { return nil }
        guard let bytes = self.buffer.getBytes(at: self.buffer.readerIndex, length: self.buffer.readableBytes) else {
            return nil
        }
        do {
            let remainingLength = try decodeRemainigLength(bytes)

            let totalLength = 1 + remainingLength.length + Int(remainingLength.value)
            guard self.buffer.readableBytes >= totalLength else { return nil } // wait for full packet

            // consume packet bytes
            guard let packetBytes = self.buffer.readSlice(length: totalLength) else { return nil }
            return try decodePacket(from: packetBytes)
        } catch {
            // for now just return nil, need to close the connection in the future
            return nil
        }
    }

    mutating func feed(buffer: ByteBuffer) -> [MQTTPacket] {
        var bytes = buffer
        self.buffer.writeBuffer(&bytes)

        var packets: [MQTTPacket] = []

        while let packet = self.parsePacket() {
            packets.append(packet)
        }

        return packets
    }

    func decodePacket(from buffer: ByteBuffer) throws -> (MQTTPacket)? {
        guard let bytes = buffer.getBytes(at: 0, length: buffer.readableBytes) else { return nil }
        // Connack
        if (bytes.starts(with: [0x20])) {
            let connack = try Connack(bytes: bytes)
            return .connack(connack)
        // Suback
        } else if (bytes.starts(with: [0x90])) {
            let suback = try Suback(bytes: bytes)
            return .suback(suback)
        // Pingresp
        } else if (bytes.starts(with: [0xd0])) {
            let pingresp = try Pingresp(bytes: bytes)
            return .pingresp(pingresp)
        // Publish
        } else if ((bytes[0] >> 4) == 3) {
            let publish = try Publish(bytes: bytes)
            return .publish(publish)
        // Pubrel
        } else if (bytes.starts(with: [0x62])){
            let pubrel = try Pubrel(bytes: bytes)
            return .pubrel(pubrel)
        // Puback
        } else if (bytes.starts(with: [0x40])) {
            let puback = try Puback(bytes: bytes)
            return .puback(puback)
        // Pubcomp
        } else if (bytes.starts(with: [0x70])) {
            let pubcomp = try Pubcomp(bytes: bytes)
            return .pubcomp(pubcomp)
        // Pubrec
        } else if (bytes.starts(with: [0x50])) {
            let pubrec = try Pubrec(bytes: bytes)
            return .pubrec(pubrec)
        } else {
            return nil
        }
    }
}
