import Dispatch
import Foundation
import Logging

@main
struct SwiftMQTT {
    static func main() async {
        // set loglevel
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .debug
            return handler
        }

        let host = "127.0.0.1"
        let port: Int = 1883
        let subscriber = MQTTClient(
            clientId: "sub-1",
            host: host,
            port: port,
            config: .init(keepAlive: 5, maxRetries: 10)
        )

        do {
            try await subscriber.connect()
        } catch {
            Log.mqtt.error("Error connecting: \(error)")
        }

        do {
            try await subscriber.subscribe(to: [
                .init(topic: "test/topic0", qos: .AtMostOnce),
                .init(topic: "test/topic1", qos: .AtLeastOnce),
                .init(topic: "test/topic2", qos: .ExactlyOnce),
            ]
            )
        } catch {
            Log.mqtt.error("Error subscribing: \(error)")
        }

        for try await event in subscriber.eventStream {
            switch event {
                case .received(let packet):
                    Log.mqtt.debug("Received: \(packet.inner().toString())")
                case .error(let error):
                    Log.mqtt.error("Error: \(error)")
                case .warning(let warning):
                    Log.mqtt.warning("Warning: \(warning)")
                case .info(let message):
                    Log.mqtt.info(.init(stringLiteral: message))
                case .send(let packet):
                    Log.mqtt.debug("Sent: \(packet.toString())")
            }
        }
    }
}
