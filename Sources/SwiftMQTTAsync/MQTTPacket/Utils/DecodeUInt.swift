import NIOCore

public func decodeUInt(from buffer: inout ByteBuffer, bytesRead: inout Int) throws -> UInt {
    var multiplier: UInt = 1
    var value: UInt = 0
    var encodedByte: UInt8 = 0

    repeat {
        guard let byte = buffer.readInteger(as: Byte.self) else {
            // TODO: throw actual error here
            throw MQTTError.unexpectedError("")
        }
        encodedByte = byte
        value += UInt((encodedByte & 0x7f)) * multiplier
        bytesRead += 1
        if (multiplier > 128*128*128) {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .malformedVariableByteInteger))
        }
        multiplier *= 128
    } while ((encodedByte & 128) != 0)

    return value
}
