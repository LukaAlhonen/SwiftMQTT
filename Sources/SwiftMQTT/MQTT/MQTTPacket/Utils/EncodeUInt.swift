func encodeUInt(_ input: UInt) -> ByteBuffer {
    var output: ByteBuffer = [];
    var X = input
    repeat {
        var encodedByte: UInt8 = UInt8(X % 128)
        X /= 128
        if (X > 0) {
            encodedByte |= 128
        }
        output.append(encodedByte)
    } while X > 0

    return output
}

func encodeUInt16(_ input: UInt16) -> ByteBuffer {
    return [
        UInt8(input >> 8),
        UInt8(input & 0xFF)
    ]
}
