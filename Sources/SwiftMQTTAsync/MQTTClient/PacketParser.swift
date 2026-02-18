import NIOCore
import NIOPosix

struct PacketParser {
    private var buffer: ByteBuffer
    private let version: Version // MQTTVersion to use for decoded packets

    init(version: Version) {
        self.buffer = .init()
        self.version = version
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
            let connack = try Connack(bytes: bytes, version: self.version)
            return .connack(connack)
        // Suback
        } else if (bytes.starts(with: [0x90])) {
            let suback = try Suback(bytes: bytes, version: self.version)
            return .suback(suback)
        // Pingresp
        } else if (bytes.starts(with: [0xd0])) {
            let pingresp = try Pingresp(bytes: bytes)
            return .pingresp(pingresp)
        // Publish
        } else if ((bytes[0] >> 4) == 3) {
            let publish = try Publish(bytes: bytes, version: self.version)
            return .publish(publish)
        // Pubrel
        } else if (bytes.starts(with: [0x62])){
            let pubrel = try Pubrel(bytes: bytes, version: self.version)
            return .pubrel(pubrel)
        // Puback
        } else if (bytes.starts(with: [0x40])) {
            let puback = try Puback(bytes: bytes, version: self.version)
            return .puback(puback)
        // Pubcomp
        } else if (bytes.starts(with: [0x70])) {
            let pubcomp = try Pubcomp(bytes: bytes, version: self.version)
            return .pubcomp(pubcomp)
        // Pubrec
        } else if (bytes.starts(with: [0x50])) {
            let pubrec = try Pubrec(bytes: bytes, version: self.version)
            return .pubrec(pubrec)
        // Unsuback
        } else if (bytes.starts(with: [0xb0])) {
            let unsuback = try Unsuback(bytes: bytes, version: self.version)
            return .unsuback(unsuback)
        // Disconnect
        } else if (bytes.starts(with: [0xe0])) {
            let disconnect = try Disconnect(bytes: bytes, version: self.version)
            return .disconnect(disconnect)
        } else {
            return nil
        }
    }
}
