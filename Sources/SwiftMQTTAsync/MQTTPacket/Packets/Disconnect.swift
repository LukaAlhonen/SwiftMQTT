public struct Disconnect: MQTTControlPacket {
    public var fixedHeader: FixedHeader

    public init() {
        self.fixedHeader = .init(type: .DISCONNECT, flags: 0, remainingLength: 0)
    }

    public func encode() -> Bytes {
        return self.fixedHeader.encode()
    }

    public func toString() -> String {
        return self.fixedHeader.toString()
    }
}
