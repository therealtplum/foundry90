import Foundation
import Combine

enum OperationType: String {
    case startStack = "Start Stack"
    case stopStack = "Stop Stack"
    case runFullEtl = "Run Full ETL"
    case exportSampleTickers = "Update Sample Tickers"
    case rebuildWebWithGit = "Rebuild Web (Current Commit)"
    case runRegression = "Run Regression"
    case panic = "PANIC"
}

final class OperationsViewModel: ObservableObject {
    @Published var isRunning = false
    @Published var currentOperation: OperationType?
    @Published var logText: String = ""

    /// Root of the capstone repo. Resolved once at init.
    private let repoRoot: URL
    
    /// Track the current process to ensure proper cleanup
    private var currentProcess: Process?

    init() {
        self.repoRoot = OperationsViewModel.resolveRepoRoot()
    }

    /// Resolve the repo root in a portable way:
    /// 1. If FOUNDRY90_ROOT is set, use that.
    /// 2. Try to find the project root by looking for the ops directory relative to common locations.
    /// 3. Otherwise, fall back to the current working directory.
    private static func resolveRepoRoot() -> URL {
        let env = ProcessInfo.processInfo.environment

        // 1. Check environment variable first
        if let envPath = env["FOUNDRY90_ROOT"],
           !envPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let url = URL(fileURLWithPath: envPath, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("ops").path) {
                return url
            }
        }

        // 2. Try common locations relative to home directory
        // Note: These are generic fallback paths. Users should set FOUNDRY90_ROOT env var instead.
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let commonPaths = [
            "\(homeDir)/Documents/python/projects/foundry90/capstones/therealtplum",
            "\(homeDir)/foundry90/capstones/therealtplum",
            "\(homeDir)/Documents/foundry90/capstones/therealtplum",
            "\(homeDir)/projects/foundry90/capstones/therealtplum",
            "\(homeDir)/code/foundry90/capstones/therealtplum",
            "\(homeDir)/Documents/projects/foundry90/capstones/therealtplum",
        ]
        
        for path in commonPaths {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("ops").path) {
                return url
            }
        }
        
        // 3. Try current working directory
        let cwd = FileManager.default.currentDirectoryPath
        let cwdURL = URL(fileURLWithPath: cwd, isDirectory: true)
        if FileManager.default.fileExists(atPath: cwdURL.appendingPathComponent("ops").path) {
            return cwdURL
        }
        
        // 4. Last resort: return a generic path (user should set FOUNDRY90_ROOT env var)
        // This will likely fail, but provides a clear error message
        let defaultPath = "\(homeDir)/foundry90/capstones/therealtplum"
        return URL(fileURLWithPath: defaultPath, isDirectory: true)
    }

    func run(_ op: OperationType) {
        // Called from main thread via SwiftUI button
        guard !isRunning else {
            // Log that we're already running to help debug
            logText.append("[\(timestamp())] Operation already in progress, ignoring \(op.rawValue)\n")
            return
        }

        // Clean up any previous process reference
        currentProcess = nil
        
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
        case .exportSampleTickers:
            scriptName = "export_sample_tickers_json.sh"
        case .rebuildWebWithGit:
            scriptName = "rebuild_web_with_git.sh"
        case .runRegression:
            scriptName = "run_regression.sh"
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
                self.logText.append(
                    "[\(self.timestamp())] Repo root resolved to: \(self.repoRoot.path)\n"
                )
                self.logText.append(
                    "[\(self.timestamp())] FOUNDRY90_ROOT env: \(ProcessInfo.processInfo.environment["FOUNDRY90_ROOT"] ?? "not set")\n"
                )
                self.logText.append(
                    "[\(self.timestamp())] Current working directory: \(FileManager.default.currentDirectoryPath)\n"
                )
                self.currentOperation = nil
            }
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        process.currentDirectoryURL = repoRoot
        
        // Store reference to process for cleanup
        currentProcess = process

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let handle = pipe.fileHandleForReading

        // Stream output into the log as it arrives
        handle.readabilityHandler = { [weak self] fh in
            let data = fh.availableData
            guard !data.isEmpty else {
                // EOF - clean up handler
                fh.readabilityHandler = nil
                return
            }
            
            guard let chunk = String(data: data, encoding: .utf8) else {
                return
            }

            Task { @MainActor in
                self?.logText.append(chunk)
            }
        }

        // When the process exits, update UI state
        process.terminationHandler = { [weak self] proc in
            // Stop reading from pipe
            handle.readabilityHandler = nil
            
            // Drain any remaining data from the pipe synchronously
            let remainingData = handle.availableData
            if !remainingData.isEmpty,
               let remainingChunk = String(data: remainingData, encoding: .utf8) {
                Task { @MainActor in
                    self?.logText.append(remainingChunk)
                }
            }
            
            // Close the file handle
            try? handle.close()

            Task { @MainActor in
                guard let self else { return }
                // Ensure state is reset
                self.isRunning = false
                self.currentProcess = nil
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
                self.currentProcess = nil
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
