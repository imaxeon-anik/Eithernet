import Foundation

enum NetworkCommandError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let value):
            return value
        }
    }
}

func runNetworkSetupSync(_ arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
    process.arguments = arguments

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    let outData = stdout.fileHandleForReading.readDataToEndOfFile()
    let errData = stderr.fileHandleForReading.readDataToEndOfFile()
    let out = String(data: outData, encoding: .utf8) ?? ""
    let err = String(data: errData, encoding: .utf8) ?? ""

    if process.terminationStatus == 0 {
        return out
    }

    let message = err.trimmingCharacters(in: .whitespacesAndNewlines)
    throw NetworkCommandError.message(
        message.isEmpty ? "networksetup failed (\(process.terminationStatus))" : message
    )
}

@discardableResult
func runNetworkSetup(_ arguments: [String]) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let out = try runNetworkSetupSync(arguments)
                continuation.resume(returning: out)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
