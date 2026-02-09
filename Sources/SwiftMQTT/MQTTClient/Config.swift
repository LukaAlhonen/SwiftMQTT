import Foundation

public struct Config: Sendable {
    public let keepAlive: UInt16
    public let pingTimeout: UInt16
    public let connTimeout: UInt16
    public let maxRetries: UInt16 // max connect retries
    public let cleanSession: Bool

    public init(keepAlive: UInt16 = 60, pingTimeout: UInt16 = 5, connTimeout: UInt16 = 30, maxRetries: UInt16 = 0, cleanSession: Bool = true) {
        self.keepAlive = keepAlive
        self.pingTimeout = pingTimeout
        self.connTimeout = connTimeout
        self.maxRetries = maxRetries
        self.cleanSession = cleanSession
    }
}

public struct LWT {
    public let topic: String
    public let message: Data
    public let qos: QoS
    public let retain: Bool

    public init(topic: String, message: Data, qos: QoS, retain: Bool) {
        self.topic = topic
        self.message = message
        self.qos = qos
        self.retain = retain
    }

    public init(topic: String, message: String, qos: QoS, retain: Bool) {
        self.topic = topic
        self.message = Data(message.utf8)
        self.qos = qos
        self.retain = retain
    }
}

public struct Auth {
    let username: String
    let password: Data?

    public init(username: String, password: Data? = nil) {
        self.username = username
        self.password = password
    }

    public init(username: String, password: String) {
        self.username = username
        self.password = Data(password.utf8)
    }
}
