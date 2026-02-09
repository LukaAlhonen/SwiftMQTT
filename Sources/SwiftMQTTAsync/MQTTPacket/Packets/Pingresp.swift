public struct Pingresp: MQTTControlPacket {
    public var fixedHeader: FixedHeader

    public init(bytes: Bytes) throws {
        guard let type = MQTTControlPacketType(rawValue: bytes[0] >> 4) else {
            throw MQTTError.protocolViolation(.malformedPacket(reason: .invalidType(expected: .PINGRESP, actual: bytes[0] >> 4)))
        }

        self.fixedHeader = FixedHeader(type: type, flags: 0, remainingLength: 0)
    }

    public init() {
        self.fixedHeader = FixedHeader(type: .PINGRESP, flags: 0, remainingLength: 0)
    }

    public func encode() -> Bytes {
        return self.fixedHeader.encode()
    }


    public func toString() -> String {
        return self.fixedHeader.toString()
    }
}
