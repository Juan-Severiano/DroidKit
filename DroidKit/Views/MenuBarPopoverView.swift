import SwiftUI

struct MenuBarPopoverView: View {
    @Bindable var viewModel: EmulatorViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            contentSection
            Divider()
            footerSection
        }
        .frame(width: 320, height: 400)
        .task { await viewModel.refresh() }
    }

    private var headerSection: some View {
        HStack {
            Text("DroidKit")
                .font(.headline)
            Spacer()
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh devices")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var contentSection: some View {
        if viewModel.sdkMissing {
            sdkMissingView
        } else if viewModel.devices.isEmpty && !viewModel.isLoading {
            emptyStateView
        } else {
            deviceListView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "android")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No devices found")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Connect a device or start an emulator")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var sdkMissingView: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text("Android SDK Not Found")
                .font(.subheadline)
                .fontWeight(.medium)
            Text("Set ANDROID_HOME or install SDK at\n~/Library/Android/sdk")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var deviceListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.devices) { device in
                    DeviceRowView(device: device, viewModel: viewModel)
                    Divider().padding(.leading, 52)
                }
            }
        }
    }

    private var footerSection: some View {
        HStack {
            if let error = viewModel.error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .lineLimit(2)
            }
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct DeviceRowView: View {
    let device: AVDevice
    let viewModel: EmulatorViewModel

    var body: some View {
        HStack(spacing: 12) {
            deviceIcon
            deviceInfo
            Spacer()
            deviceAction
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var deviceIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: 32, height: 32)
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundStyle(iconForegroundColor)
        }
    }

    private var deviceInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(device.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            HStack(spacing: 4) {
                statusIndicator
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 6, height: 6)
    }

    private var statusText: String {
        switch device.status {
        case .stopped: return "Stopped"
        case .starting: return "Starting..."
        case .running: return "Connected"
        case .stopping: return "Stopping..."
        }
    }

    @ViewBuilder
    private var deviceAction: some View {
        switch device.kind {
        case .emulator:
            emulatorActions
        case .usbDevice:
            usbActions
        case .wifiDevice:
            wifiActions
        }
    }

    @ViewBuilder
    private var emulatorActions: some View {
        switch device.status {
        case .stopped:
            Button {
                viewModel.launch(device)
            } label: {
                Text("Start")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        case .starting, .stopping:
            ProgressView()
                .controlSize(.small)
        case .running:
            Button {
                viewModel.stop(device)
            } label: {
                Text("Stop")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var usbActions: some View {
        if device.status == .starting {
            ProgressView()
                .controlSize(.small)
        } else {
            Button {
                Task { await viewModel.convertToWiFi(device) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "wifi")
                        .font(.caption2)
                    Text("Connect")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var wifiActions: some View {
        Button {
            Task { await viewModel.disconnectWiFi(device) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "wifi.slash")
                    .font(.caption2)
                Text("Disconnect")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .controlSize(.small)
    }

    private var iconName: String {
        switch device.kind {
        case .emulator: return "desktopcomputer"
        case .usbDevice: return "cable.connector"
        case .wifiDevice: return "wifi"
        }
    }

    private var iconBackgroundColor: Color {
        switch device.kind {
        case .emulator: return .blue.opacity(0.15)
        case .usbDevice: return .green.opacity(0.15)
        case .wifiDevice: return .purple.opacity(0.15)
        }
    }

    private var iconForegroundColor: Color {
        switch device.kind {
        case .emulator: return .blue
        case .usbDevice: return .green
        case .wifiDevice: return .purple
        }
    }

    private var statusColor: Color {
        switch device.status {
        case .stopped: return .gray
        case .starting: return .yellow
        case .running: return .green
        case .stopping: return .orange
        }
    }
}
