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
    @Published var statusMessage: String?
    @Published var lastBackupPath: String?

    private let interface = "en0"
    private var originalNetworks: [String] = []
    private let backupDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".wifi-priority-backups")

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
        statusMessage = "💾 Creating backup..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Backup before making changes
            if let backupPath = self.backupNetworks() {
                DispatchQueue.main.async {
                    self.lastBackupPath = backupPath
                    self.statusMessage = "✅ Backup saved"
                }
            }

            // Find networks that actually changed position
            var changedIndices = Set<Int>()
            for i in 0..<self.networks.count {
                if i >= self.originalNetworks.count || self.originalNetworks[i] != self.networks[i] {
                    changedIndices.insert(i)
                }
            }

            // Networks that were removed
            let removedNetworks = Set(self.originalNetworks).subtracting(Set(self.networks))

            // Networks to modify: those that changed position or were removed
            var networksToModify = Set<String>()
            for i in changedIndices {
                networksToModify.insert(self.networks[i])
            }
            networksToModify.formUnion(removedNetworks)

            DispatchQueue.main.async {
                self.statusMessage = "💾 Backup created"
            }

            // Build a single shell script with all commands to avoid multiple password prompts
            var commands: [String] = []

            // Remove only networks that changed or were deleted
            for network in networksToModify {
                let escapedNetwork = network.replacingOccurrences(of: "'", with: "'\\''")
                commands.append("/usr/sbin/networksetup -removepreferredwirelessnetwork '\(self.interface)' '\(escapedNetwork)'")
                commands.append("sleep 0.05")
            }

            // Wait for macOS to process removals
            commands.append("sleep 0.5")

            DispatchQueue.main.async {
                self.statusMessage = "💾 Updating networks... (removing \(networksToModify.count))"
            }

            // Re-add ALL networks in new priority order to set correct priorities
            // Even unchanged networks need to be re-added to maintain correct order
            for network in self.networks.reversed() {
                let escapedNetwork = network.replacingOccurrences(of: "'", with: "'\\''")
                commands.append("/usr/sbin/networksetup -addpreferredwirelessnetworkatindex '\(self.interface)' '\(escapedNetwork)' 0 ''")
                commands.append("sleep 0.1")
            }

            DispatchQueue.main.async {
                self.statusMessage = "💾 Re-adding networks in priority order..."
            }

            // Execute all commands in one sudo session
            let result = self.executeBatchSudoCommands(commands)

            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success:
                    self.originalNetworks = self.networks
                    self.statusMessage = "✅ Networks updated successfully!"
                    completion(.success(()))
                case .failure(let error):
                    self.statusMessage = nil
                    completion(.failure(error))
                }
            }
        }
    }

    func moveNetwork(from source: IndexSet, to destination: Int) {
        networks.move(fromOffsets: source, toOffset: destination)
    }

    func resetChanges() {
        networks = originalNetworks
    }

    private func loadSecurityTypesFromPlist() -> [String: String] {
        var securityTypes: [String: String] = [:]
        let plistPath = "/Library/Preferences/com.apple.wifi.known-networks.plist"

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)) else {
            return securityTypes
        }

        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return securityTypes
        }

        if let knownNetworks = plist["KnownNetworks"] as? [[String: Any]] {
            for networkInfo in knownNetworks {
                if let ssid = networkInfo["SSID_STR"] as? String {
                    let securityType = (networkInfo["SecurityType"] as? String) ?? "Unknown"
                    securityTypes[ssid] = securityType
                }
            }
        }

        return securityTypes
    }

    private func backupNetworks() -> String? {
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let backupFile = backupDir.appendingPathComponent("networks_\(timestamp).txt")

        let securityTypes = loadSecurityTypesFromPlist()

        var content = "# WiFi Priority Backup - \(Date())\n"
        content += "# Interface: \(interface)\n"
        content += "# Networks: \(originalNetworks.count)\n"
        content += "# Format: name|security_type\n"
        content += "# (security_type is informational; macOS uses Keychain for credentials)\n"
        content += "#\n"
        // Write networks with security types from plist
        content += originalNetworks.map { network in
            let securityType = securityTypes[network] ?? "Unknown"
            return "\(network)|\(securityType)"
        }.joined(separator: "\n")

        try? content.write(to: backupFile, atomically: true, encoding: .utf8)

        // Clean up old backups (keep last 10)
        if let backups = try? FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            .dropLast(10) {
            for oldBackup in backups {
                try? FileManager.default.removeItem(at: oldBackup)
            }
        }

        return backupFile.path
    }

    func restoreFromLatestBackup(completion: @escaping (Result<Void, NetworkError>) -> Void) {
        isLoading = true
        statusMessage = "📂 Loading latest backup..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Find latest backup file
            guard let backups = try? FileManager.default.contentsOfDirectory(at: self.backupDir, includingPropertiesForKeys: nil)
                .sorted(by: { $0.lastPathComponent > $1.lastPathComponent }),
              let latestBackup = backups.first else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(.failure(.commandFailed("No backup files found")))
                }
                return
            }

            // Read backup file
            guard let content = try? String(contentsOf: latestBackup, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(.failure(.commandFailed("Could not read backup file")))
                }
                return
            }

            // Parse networks from backup (skip comments, handle pipe-separated format)
            var restoredNetworks: [String] = []
            for line in content.split(separator: "\n") {
                let trimmed = String(line).trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty && !trimmed.starts(with: "#") else { continue }

                // Handle new format: "network_name|security_type"
                let networkName = trimmed.split(separator: "|", maxSplits: 1).first.map(String.init) ?? trimmed
                restoredNetworks.append(networkName)
            }

            DispatchQueue.main.async {
                self.statusMessage = "🔄 Restoring \(restoredNetworks.count) networks..."
            }

            // Build restore command script
            var commands: [String] = []

            // Remove all current networks
            for network in self.originalNetworks {
                let escapedNetwork = network.replacingOccurrences(of: "'", with: "'\\''")
                commands.append("/usr/sbin/networksetup -removepreferredwirelessnetwork '\(self.interface)' '\(escapedNetwork)'")
            }

            commands.append("sleep 0.5")

            // Add restored networks in order
            for network in restoredNetworks.reversed() {
                let escapedNetwork = network.replacingOccurrences(of: "'", with: "'\\''")
                commands.append("/usr/sbin/networksetup -addpreferredwirelessnetworkatindex '\(self.interface)' '\(escapedNetwork)' 0 ''")
                commands.append("sleep 0.1")
            }

            let result = self.executeBatchSudoCommands(commands)

            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success:
                    self.originalNetworks = restoredNetworks
                    self.networks = restoredNetworks
                    self.statusMessage = "✅ Networks restored!"
                    completion(.success(()))
                case .failure(let error):
                    self.statusMessage = nil
                    completion(.failure(error))
                }
            }
        }
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
        // Properly escape arguments for shell execution
        let escapedArgs = arguments.map { arg -> String in
            // Escape single quotes and backslashes, then wrap in single quotes
            let escaped = arg.replacingOccurrences(of: "\\", with: "\\\\")
                             .replacingOccurrences(of: "'", with: "'\\''")
            return "'\(escaped)'"
        }.joined(separator: " ")

        let script = """
        do shell script "\(command) \(escapedArgs)" with administrator privileges
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

    private func executeBatchSudoCommands(_ commands: [String]) -> Result<Void, NetworkError> {
        // Execute all commands in a single sudo session to avoid multiple password prompts
        let shellScript = commands.joined(separator: "; ")

        // Escape for AppleScript (escape backslashes and quotes)
        let escapedScript = shellScript
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        do shell script "\(escapedScript)" with administrator privileges
        """

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?

        guard appleScript?.executeAndReturnError(&error) != nil else {
            if let error = error {
                return .failure(.commandFailed(error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"))
            }
            return .failure(.commandFailed("Failed to execute commands"))
        }

        return .success(())
    }
}
