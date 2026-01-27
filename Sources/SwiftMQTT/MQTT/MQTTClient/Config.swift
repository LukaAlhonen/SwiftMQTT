import Foundation

struct Config {
    let keepAlive: UInt16
    let pingTimeout: UInt16
    let connTimeout: UInt16
    let maxRetries: UInt16 // max connect retries
    let cleanSession: Bool

    init(keepAlive: UInt16 = 60, pingTimeout: UInt16 = 5, connTimeout: UInt16 = 30, maxRetries: UInt16 = 0, cleanSession: Bool = true) {
        self.keepAlive = keepAlive
        self.pingTimeout = pingTimeout
        self.connTimeout = connTimeout
        self.maxRetries = maxRetries
        self.cleanSession = cleanSession
    }
}

struct LWT {
    let topic: String
    let message: Data
    let qos: QoS
    let retain: Bool

    init(topic: String, message: Data, qos: QoS, retain: Bool) {
        self.topic = topic
        self.message = message
        self.qos = qos
        self.retain = retain
    }

    init(topic: String, message: String, qos: QoS, retain: Bool) {
        self.topic = topic
        self.message = Data(message.utf8)
        self.qos = qos
        self.retain = retain
    }
}

struct Auth {
    let username: String
    let password: Data?

    init(username: String, password: Data? = nil) {
        self.username = username
        self.password = password
    }

    init(username: String, password: String) {
        self.username = username
        self.password = Data(password.utf8)
    }
}
