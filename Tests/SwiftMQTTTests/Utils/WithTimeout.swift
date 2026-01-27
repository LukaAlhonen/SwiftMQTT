enum TestError: Error {
    case timeout
    case emptyPacketStream
}

func withTimeout<T: Sendable>(seconds: UInt16, operation: @Sendable @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(for: .seconds(Double(seconds)))
            throw TestError.timeout
        }

        let result = try await group.next()!
        group.cancelAll()

        return result
    }
}
