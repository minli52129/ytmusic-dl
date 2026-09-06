import Foundation

final class YtDlpRunner {
    var onLine: ((String) -> Void)?
    var onTerminate: ((Int32) -> Void)?

    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    private var buffer = Data()

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let current = process
        lock.unlock()
        guard let current, current.isRunning else { return }
        current.interrupt()
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak current] in
            if let current, current.isRunning {
                current.terminate()
            }
        }
    }

    func run(executable: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "en_US.UTF-8"
        process.environment = environment
        process.qualityOfService = .userInitiated

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        lock.lock()
        self.process = process
        lock.unlock()

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let self else { return }
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            self.consume(data)
        }

        process.terminationHandler = { [weak self] _ in
            guard let self else { return }
            let handle = pipe.fileHandleForReading
            handle.readabilityHandler = nil
            let rest = handle.readDataToEndOfFile()
            if !rest.isEmpty {
                self.consume(rest)
            }
            self.consume(Data("\n".utf8))
            self.onTerminate?(process.terminationStatus)
        }

        try process.run()
    }

    private func consume(_ data: Data) {
        var lines: [String] = []
        lock.lock()
        buffer.append(data)
        while let index = buffer.firstIndex(of: UInt8(0x0A)) {
            let lineData = buffer.subdata(in: 0..<index)
            buffer.removeSubrange(0...index)
            if let line = String(data: lineData, encoding: .utf8) {
                lines.append(line)
            }
        }
        lock.unlock()
        for line in lines {
            onLine?(line)
        }
    }
}
