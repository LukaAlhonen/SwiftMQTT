import Dispatch
import Foundation
import Logging

@main
struct SwiftMQTT {
    static func main() async {
        // set loglevel
        // TODO: update client to take logger as input
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = .debug
            return handler
        }

        let host = "127.0.0.1"
        let port: Int = 1883
        let subscriber = MQTTClient(
            host: host,
            port: port,
            clientId: "sub-1",
            config: .init(keepAlive: 5)
        )

        do {
            try await subscriber.start()
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

        do {
            for try await packet in subscriber.packetStream {
                switch packet {
                    case .publish(let publish):
                        // Log.mqtt.info("PUBLISH: \(publish.payload.toString()), on topic \(publish.varHeader.topicName)")
                        Log.mqtt.info(.init(stringLiteral: publish.toString()))
                    case .pingresp(let pingresp):
                        Log.mqtt.debug(.init(stringLiteral: pingresp.toString()))
                    case .connack(let connack):
                        Log.mqtt.debug(.init(stringLiteral: connack.toString()))
                    default:
                        Log.mqtt.debug("Received: \(packet)")
                }
            }
        } catch {
            Log.mqtt.error("Error: \(error)")
        }
    }
}
