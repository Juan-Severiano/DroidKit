import SwiftUI

struct MenuBarPopoverView: View {
    @Bindable var viewModel: EmulatorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 300)
        .task { await viewModel.refresh() }
    }

    private var header: some View {
        HStack {
            Text("DroidKit").font(.headline)
            Spacer()
            if viewModel.isLoading {
                ProgressView().controlSize(.small)
            } else {
                Button { Task { await viewModel.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.sdkMissing {
            sdkMissingView
        } else if viewModel.devices.isEmpty && !viewModel.isLoading {
            Text("No AVDs found")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.devices) { device in
                        DeviceRow(device: device, viewModel: viewModel)
                        Divider().padding(.leading, 36)
                    }
                }
            }
            .frame(maxHeight: 320)
            wifiConnectRow
        }
    }

    private var sdkMissingView: some View {
        VStack(spacing: 4) {
            Text("Android SDK not found").foregroundStyle(.secondary)
            Text("Set ANDROID_HOME or install SDK at\n~/Library/Android/sdk")
                .font(.caption).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.horizontal, 12)
    }

    private var wifiConnectRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi")
                .foregroundStyle(.secondary)
            TextField("IP address", text: $viewModel.wifiHost)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
            if viewModel.isConnectingWiFi {
                ProgressView().controlSize(.small)
            } else {
                Button("Connect") { Task { await viewModel.connectWiFi() } }
                    .controlSize(.small)
                    .disabled(viewModel.wifiHost.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack {
            if let err = viewModel.error {
                Text(err).font(.caption).foregroundStyle(.red).lineLimit(2)
            }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

struct DeviceRow: View {
    let device: AVDevice
    let viewModel: EmulatorViewModel

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(device.name).lineLimit(1)
            Spacer()
            actionButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch device.status {
        case .stopped:  .gray
        case .starting: .yellow
        case .running:  .green
        case .stopping: .orange
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch device.kind {
        case .usbDevice:
            usbActionButton
        case .emulator:
            emulatorActionButton
        case .wifiDevice:
            Button("Disconnect") { Task { await viewModel.disconnectWiFi(device) } }
                .controlSize(.small)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var usbActionButton: some View {
        if device.status == .starting {
            ProgressView().controlSize(.small)
        } else {
            Button("To Wi-Fi") { Task { await viewModel.convertToWiFi(device) } }
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private var emulatorActionButton: some View {
        switch device.status {
        case .stopped:
            Button("Start") { viewModel.launch(device) }.controlSize(.small)
        case .starting, .stopping:
            ProgressView().controlSize(.small)
        case .running:
            Button("Stop") { viewModel.stop(device) }
                .controlSize(.small)
                .foregroundStyle(.red)
        }
    }
}
