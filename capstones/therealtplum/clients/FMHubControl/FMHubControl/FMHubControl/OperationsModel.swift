import Foundation
import Combine

enum OperationType: String {
    case startStack = "Start Stack"
    case stopStack = "Stop Stack"
    case runFullEtl = "Run Full ETL"
    case rebuildWebWithGit = "Rebuild Web (Current Commit)"
    case panic = "PANIC"
}

final class OperationsViewModel: ObservableObject {
    @Published var isRunning = false
    @Published var currentOperation: OperationType?
    @Published var logText: String = ""

    /// Root of the capstone repo. Resolved once at init.
    private let repoRoot: URL

    init() {
        self.repoRoot = OperationsViewModel.resolveRepoRoot()
    }

    /// Resolve the repo root in a portable way:
    /// 1. If FOUNDRY90_ROOT is set, use that.
    /// 2. Otherwise, fall back to the current working directory.
    private static func resolveRepoRoot() -> URL {
        let env = ProcessInfo.processInfo.environment

        if let envPath = env["FOUNDRY90_ROOT"],
           !envPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: envPath, isDirectory: true)
        }

        let cwd = FileManager.default.currentDirectoryPath
        return URL(fileURLWithPath: cwd, isDirectory: true)
    }

    func run(_ op: OperationType) {
        // Called from main thread via SwiftUI button
        guard !isRunning else { return }

        isRunning = true
        currentOperation = op
        logText = "[\(timestamp())] Running \(op.rawValue)...\n"

        runScript(for: op)
    }

    private func runScript(for op: OperationType) {
        let scriptName: String
        switch op {
        case .startStack:
            scriptName = "start_stack.sh"
        case .stopStack:
            scriptName = "stop_stack.sh"
        case .runFullEtl:
            scriptName = "run_full_etl.sh"
        case .rebuildWebWithGit:
            scriptName = "rebuild_web_with_git.sh"
        case .panic:
            scriptName = "panic.sh"
        }

        let scriptURL = repoRoot
            .appendingPathComponent("ops")
            .appendingPathComponent(scriptName)

        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            Task { @MainActor in
                self.isRunning = false
                self.logText.append(
                    "\n[\(self.timestamp())] Script not found at \(scriptURL.path)\n"
                )
                self.currentOperation = nil
            }
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        process.currentDirectoryURL = repoRoot

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let handle = pipe.fileHandleForReading

        // Stream output into the log as it arrives
        handle.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty,
                  let chunk = String(data: data, encoding: .utf8) else { return }

            Task { @MainActor in
                self?.logText.append(chunk)
            }
        }

        // When the process exits, update UI state
        process.terminationHandler = { [weak self] proc in
            handle.readabilityHandler = nil

            Task { @MainActor in
                guard let self else { return }
                self.isRunning = false
                let status = proc.terminationStatus
                if status == 0 {
                    self.logText.append(
                        "\n[\(self.timestamp())] \(op.rawValue) completed successfully.\n"
                    )
                } else {
                    self.logText.append(
                        "\n[\(self.timestamp())] \(op.rawValue) failed with code \(status).\n"
                    )
                }
                self.currentOperation = nil
            }
        }

        do {
            try process.run()
        } catch {
            handle.readabilityHandler = nil
            Task { @MainActor in
                self.isRunning = false
                self.logText.append(
                    "\n[\(self.timestamp())] Failed to start process: \(error.localizedDescription)\n"
                )
                self.currentOperation = nil
            }
        }
    }

    private func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: Date())
    }
}
