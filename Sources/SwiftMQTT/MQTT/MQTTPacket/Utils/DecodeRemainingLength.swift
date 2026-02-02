func decodeRemainigLength(_ data: Bytes) throws -> (value: UInt, length: Int) {
    var multiplier: UInt = 1
    var value: UInt = 0
    var index: Int = 1
    var encodedByte: UInt8 = 0

    repeat {
        // guard index < data.count else {
        //     throw MQTTError.DecodePacketError(message: "Malformed remaining length")
        // }
        encodedByte = data[index]
        value += UInt((encodedByte & 0x7f)) * multiplier
        multiplier *= 128
        index += 1

        if (multiplier > 128*128*128*128) {
            throw MQTTError.DecodePacketError(message: "Malformed remaining length")
        }
    } while ((encodedByte & 128) != 0)

    return (value, index-1)
}
