//
//  ContentView.swift
//  WiFiPrioritySwiftUI
//
//  Main UI for WiFi network priority management
//

import SwiftUI

struct ContentView: View {
    @StateObject private var networkManager = NetworkManager()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()

            // Instructions
            InstructionsView()
                .padding(.horizontal)
                .padding(.top, 8)

            // Network List
            if networkManager.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)

                    Text(networkManager.statusMessage ?? "Loading networks...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = networkManager.errorMessage {
                ErrorView(error: error, onRetry: networkManager.loadNetworks)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NetworkListView(networks: $networkManager.networks, onMove: networkManager.moveNetwork)
                    .padding()
            }

            // Status Bar
            StatusBarView(hasChanges: networkManager.hasChanges)

            // Action Buttons
            ActionButtonsView(
                hasChanges: networkManager.hasChanges,
                isLoading: networkManager.isLoading,
                onSave: saveChanges,
                onReset: networkManager.resetChanges,
                onQuit: quitApp
            )
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            // Refresh network list when view appears
            networkManager.loadNetworks()
        }
        .onChange(of: scenePhase) { newPhase in
            // Refresh when app becomes active
            if newPhase == .active {
                networkManager.loadNetworks()
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            if alertTitle == "Success" {
                Button("Quit") {
                    quitApp()
                }
                Button("Keep Open", role: .cancel) { }
            } else {
                Button("OK", role: .cancel) { }
            }
        } message: {
            Text(alertMessage)
        }
    }

    private func saveChanges() {
        networkManager.saveNetworks { result in
            switch result {
            case .success:
                alertTitle = "Success"
                alertMessage = "WiFi network priorities updated successfully!"
                showingAlert = true
            case .failure(let error):
                alertTitle = "Error"
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Header View

struct HeaderView: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi")
                .font(.title2)
                .foregroundColor(.blue)
            Text("WiFi Network Priority Manager")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.1))
    }
}

// MARK: - Instructions View

struct InstructionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Higher position = preferred network")
                    .font(.subheadline)
            }
            HStack {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(.blue)
                Text("Drag networks to reorder • Save to apply changes")
                    .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Network List View

struct NetworkListView: View {
    @Binding var networks: [String]
    let onMove: (IndexSet, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WiFi Networks (Priority Order)")
                .font(.headline)
                .padding(.bottom, 4)

            if networks.isEmpty {
                Text("No WiFi networks found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(networks.enumerated()), id: \.element) { index, network in
                        NetworkRowView(network: network, position: index + 1)
                    }
                    .onMove(perform: onMove)
                }
                .listStyle(.inset)
            }
        }
    }
}

// MARK: - Network Row View

struct NetworkRowView: View {
    let network: String
    let position: Int

    var body: some View {
        HStack {
            Text("\(position)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)

            Image(systemName: "wifi")
                .foregroundColor(.blue)

            Text(network)
                .font(.body)

            Spacer()

            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Bar View

struct StatusBarView: View {
    let hasChanges: Bool

    var body: some View {
        HStack {
            Image(systemName: hasChanges ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(hasChanges ? .orange : .green)

            Text(hasChanges ? "Changes not saved!" : "No changes made")
                .font(.subheadline)

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}

// MARK: - Action Buttons View

struct ActionButtonsView: View {
    let hasChanges: Bool
    let isLoading: Bool
    let onSave: () -> Void
    let onReset: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if hasChanges {
                Button("Reset") {
                    onReset()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }

            Spacer()

            Button("Quit") {
                onQuit()
            }
            .keyboardShortcut("q", modifiers: [.command])

            Button("Save & Quit") {
                onSave()
            }
            .keyboardShortcut("s", modifiers: [.command])
            .buttonStyle(.borderedProminent)
            .disabled(!hasChanges || isLoading)
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("Error Loading Networks")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
