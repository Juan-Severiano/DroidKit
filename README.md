# DroidKit

DroidKit is a macOS Menu Bar app for managing Android Virtual Devices (AVDs) and physical Android devices (via USB and Wi-Fi) directly from your Mac menu bar. With a simple, modern interface, DroidKit streamlines Android emulator management and device connectivity — without needing to use the command line.

## Features

- 🖥️ **Menu Bar Experience**: Access your Android emulators and devices from anywhere.
- 🚀 **List & Launch AVDs**: See all your installed Android Virtual Devices. Start or stop them instantly.
- 🔌 **Detect Physical Devices**: Connected Android devices via USB are automatically detected.
- 📡 **Wi-Fi Debugging**: Seamless conversion from USB to Wi-Fi debugging for physical devices.
- 💡 **Status Overview**: See at-a-glance which devices are connected, running, or stopped.
- 🛠️ **Automatic SDK Path Detection**: No manual setup required if you use standard `ANDROID_HOME` or default install locations.

## Screenshots

https://github.com/user-attachments/assets/4d0084e6-c41f-455c-bf03-dd1ba9ea6d34



## Getting Started

### Prerequisites
- macOS 13.0 or later
- [Android SDK](https://developer.android.com/tools/sdk) installed
    - Ensure the `ANDROID_HOME` or `ANDROID_SDK_ROOT` environment variable is set, **or**
    - Install the SDK at `~/Library/Android/sdk`

### Building

1. Open the project in Xcode.
2. Build and run the app (⌘R). The DroidKit icon will appear in your menu bar.

### Usage
- Click the DroidKit icon in the menu bar to open the device manager.
- Start/stop emulators, connect/disconnect devices, and convert USB devices to Wi-Fi debugging — all in one place.

## Troubleshooting
- **Android SDK Not Found**: Make sure your SDK is installed and `ANDROID_HOME` or `ANDROID_SDK_ROOT` is set, or install to the default location.
- **Device Not Detected**: Ensure your device has USB debugging enabled and is authorized for your Mac.

## Contributing
Contributions are welcome! Please open issues or pull requests as needed.

## License
Copyright © 2026 DroidKit Contributors. See `LICENSE` for details.
