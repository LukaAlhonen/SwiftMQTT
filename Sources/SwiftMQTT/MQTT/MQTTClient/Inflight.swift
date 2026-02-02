enum InflightState {
    case publishQoS1(PublishQoS1State)
    case publishQoS2(PublishQoS2State)
    case subscribe(SubscribeState)
}

struct InflightTask {
    var state: InflightState
    var timeout: TimeoutTask?
}

final class TimeoutTask: @unchecked Sendable {
    private var task: Task<Void, Never>?
    private var cont: CheckedContinuation<Void, Error>?
    private var timeout: Duration
    private var completedResult: Result<Void, Error>?

    init(timeout: UInt16) {
        self.timeout = .seconds(Double(timeout))
    }

    func start() {
        guard task == nil else {
            return
        }

        self.task = Task {
            do {
                try await Task.sleep(for: self.timeout)
                self.finish(result: .failure(MQTTError.Timeout(reason: "Task timed out")))
            } catch {
                // timer cancelled
            }
        }
    }

    private func finish(result: Result<Void, Error>) {
        if let cont = self.cont {
            self.cont = nil
            self.task?.cancel()
            self.task = nil

            switch result {
            case .success:
                cont.resume()
            case .failure(let error):
                cont.resume(throwing: error)
            }
        } else {
            self.completedResult = result
            self.task?.cancel()
            self.task = nil
        }
    }

    func stop() {
        self.finish(result: .success(()))
    }

    func wait() async throws {
        try await withCheckedThrowingContinuation { cont in
            if let result = self.completedResult {
                self.resume(cont: cont, result: result)
            } else {
                self.cont = cont
            }
        }
    }

    private func resume(cont: CheckedContinuation<Void, Error>, result: Result<Void, Error>) {
        switch result {
        case .success:
            cont.resume()
        case .failure(let error):
            cont.resume(throwing: error)
        }
    }
}
