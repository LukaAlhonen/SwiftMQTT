import Logging

enum Log {
    static let mqtt = Logger(label: "MQTT")
    static let tcp = Logger(label: "TCP")
}
