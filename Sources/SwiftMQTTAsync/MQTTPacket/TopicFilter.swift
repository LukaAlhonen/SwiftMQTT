public struct TopicFilter: Hashable, Sendable {
    public let topic: String
    public let qos: QoS
    public let retainHandling: Byte
    public let rap: Byte
    public let nl: Byte
    public init(
        topic: String, retainHandling: Byte = 0, rap: Bool = false, nl: Bool = false, qos: QoS
    ) {
        self.topic = topic
        self.retainHandling = retainHandling
        self.rap = rap ? 1 : 0
        self.nl = nl ? 1 : 0
        self.qos = qos
    }
}

extension TopicFilter {
    public func encode() -> Bytes {
        var bytes: Bytes = []

        let topicBytes = Bytes(self.topic.utf8)
        bytes.append(contentsOf: encodeUInt16(UInt16(topicBytes.count)))
        bytes.append(contentsOf: topicBytes)

        var optionsByte: Byte = 0b00000000
        // retain handling
        optionsByte |= retainHandling << 4
        // retain as published
        optionsByte |= rap << 3
        // no local
        optionsByte |= nl << 2
        // QoS
        optionsByte |= qos.rawValue

        bytes.append(optionsByte)

        return bytes
    }
}
