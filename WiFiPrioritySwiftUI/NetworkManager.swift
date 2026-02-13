//
//  NetworkManager.swift
//  WiFiPrioritySwiftUI
//
//  Manages WiFi network priorities using macOS networksetup command
//

import Foundation

enum NetworkError: Error {
    case commandFailed(String)
    case networkAddFailed(String, String)

    var localizedDescription: String {
        switch self {
        case .commandFailed(let message):
            return message
        case .networkAddFailed(let network, let error):
            return "Failed to add network '\(network)': \(error)"
        }
    }
}

class NetworkManager: ObservableObject {
    @Published var networks: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let interface = "en0"
    private var originalNetworks: [String] = []

    var hasChanges: Bool {
        networks != originalNetworks
    }

    init() {
        loadNetworks()
    }

    func loadNetworks() {
        isLoading = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let result = self.executeCommand(
                "/usr/sbin/networksetup",
                arguments: ["-listpreferredwirelessnetworks", self.interface]
            )

            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success(let output):
                    self.parseNetworks(output)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func saveNetworks(completion: @escaping (Result<Void, NetworkError>) -> Void) {
        guard hasChanges else {
            completion(.success(()))
            return
        }

        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Remove all networks first
            for network in self.originalNetworks {
                _ = self.executeSudoCommand(
                    "/usr/sbin/networksetup",
                    arguments: ["-removepreferredwirelessnetwork", self.interface, network]
                )
            }

            // Wait for macOS to process all removals
            Thread.sleep(forTimeInterval: 0.5)

            // Add networks in reverse order (last added = highest priority)
            // Don't specify security type - macOS uses existing credentials from Keychain
            for network in self.networks.reversed() {
                let result = self.executeSudoCommand(
                    "/usr/sbin/networksetup",
                    arguments: ["-addpreferredwirelessnetworkatindex", self.interface, network, "0", ""]
                )

                if case .failure(let error) = result {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        completion(.failure(.networkAddFailed(network, error.localizedDescription)))
                    }
                    return
                }

                // Small delay to ensure macOS processes each addition sequentially
                Thread.sleep(forTimeInterval: 0.1)
            }

            DispatchQueue.main.async {
                self.originalNetworks = self.networks
                self.isLoading = false
                completion(.success(()))
            }
        }
    }

    func moveNetwork(from source: IndexSet, to destination: Int) {
        networks.move(fromOffsets: source, toOffset: destination)
    }

    func resetChanges() {
        networks = originalNetworks
    }

    // MARK: - Private Methods

    private func parseNetworks(_ output: String) {
        let lines = output.split(separator: "\n")

        // Skip the header line "Preferred networks on en0:"
        let networkLines = lines.dropFirst().map { line in
            line.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        networks = Array(networkLines)
        originalNetworks = networks
    }

    private func executeCommand(_ command: String, arguments: [String]) -> Result<String, NetworkError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let error = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return .failure(.commandFailed(error))
            }

            return .success(output)
        } catch {
            return .failure(.commandFailed(error.localizedDescription))
        }
    }

    private func executeSudoCommand(_ command: String, arguments: [String]) -> Result<String, NetworkError> {
        // For sudo commands, we need to use AppleScript to prompt for password
        let script = """
        do shell script "\(command) \(arguments.map { "\"\($0)\"" }.joined(separator: " "))" with administrator privileges
        """

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?

        guard let result = appleScript?.executeAndReturnError(&error) else {
            if let error = error {
                return .failure(.commandFailed(error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"))
            }
            return .failure(.commandFailed("Failed to execute command"))
        }

        return .success(result.stringValue ?? "")
    }
}
