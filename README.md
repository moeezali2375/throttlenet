# ThrottleNet 🚀

A lightweight, native macOS menu bar and dashboard application to monitor per-process network traffic in real-time and throttle bandwidth (upload & download speed limits) for individual processes.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-macOS-purple)

---

## ✨ Features

- **Real-Time Network Monitoring**: Continuously measures download and upload bandwidth per process (KB/s, MB/s) with delta rate calculations and mini live sparklines.
- **Per-Process Bandwidth Throttling**: Configure independent **Download** and **Upload** limits for any process (such as `cloudd`, iCloud Drive sync, OneDrive, Dropbox, browsers, etc.).
- **Interactive Limit Controls**:
  - Fine-grained speed sliders.
  - Direct numeric speed input (in KB/s or MB/s).
  - Quick-preset chips (`100 KB/s`, `250 KB/s`, `500 KB/s`, `1 MB/s`, `2 MB/s`, `5 MB/s`, `10 MB/s`).
- **Dynamic Socket Tracking**: Dynamically tracks open TCP/UDP sockets for throttled PIDs so new connections created by the target process are automatically rate-limited.
- **Menu Bar & Dashboard UI**: Sleek macOS SwiftUI interface with global aggregate metrics, search bar, process filters (`All`, `Active Traffic`, `Throttled`, `User Apps`), and multi-field sorting.
- **Safe & Clean Teardown**: Automatically releases all `pf` anchors and `dnctl` pipes on exit or with the "Reset All" button.

---

## 🛠 How It Works Under The Hood

```
┌────────────────────────────────────────────────────────┐
│               SwiftUI Application (UI)                 │
│  - Menu Bar Item / Window Dashboard                    │
│  - Real-time Process Bandwidth List (Up/Down KB/s)     │
│  - Per-process Throttle Slider & Numeric Speed Limits  │
└──────────────────────────┬─────────────────────────────┘
                           │ App State / Combine
┌──────────────────────────▼─────────────────────────────┐
│                 Core Network Engine                    │
│  ┌──────────────────────────┐┌───────────────────────┐ │
│  │ Process Network Monitor  ││   Socket Inspector    │ │
│  │ (nettop / libproc)       ││ (lsof / proc_pidinfo) │ │
│  └──────────────────────────┘└───────────────────────┘ │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│             macOS Traffic Shaping Layer                │
│  - dnctl (Dummynet): Configures bandwidth pipes (KB/s) │
│  - pfctl (Packet Filter): Routes socket traffic to pipe│
└────────────────────────────────────────────────────────┘
```

1. **Diagnostic Bandwidth Polling**:
   `NetworkMonitor` samples the macOS network diagnostic subsystem (`nettop`) to obtain exact per-process `bytes_in` and `bytes_out` deltas with minimal CPU overhead.

2. **Dummynet Traffic Shaping (`dnctl`)**:
   When a process is throttled, `TrafficShaper` creates dedicated Dummynet pipes (e.g. `dnctl pipe 1000 config bw 500Kbyte/s`).

3. **Packet Filter Anchors (`pfctl`)**:
   `SocketTracker` inspects the target PID's open local socket ports using `lsof`. Dynamic packet filter rules are injected into a dedicated `throttlenet/<pid>` anchor to direct traffic through the configured Dummynet pipes.

---

## 📁 Project Structure

```
throttlenet/
├── Package.swift                             # Swift Package Manager manifest
├── Resources/                                # App Icons & Graphic Assets
│   ├── AppIcon.icns                          # Native macOS multi-resolution icon bundle
│   ├── AppIcon.png                           # Master 1024x1024 app icon
│   ├── AppIconMinimal.icns                   # Alternative minimal neon icon bundle
│   └── AppIconMinimal.png                    # Alternative minimal master icon
├── Sources/
│   ├── ThrottleNetCore/                      # Core Library
│   │   ├── Models/
│   │   │   ├── ProcessNetworkInfo.swift      # Process bandwidth & metadata model
│   │   │   ├── SpeedUnit.swift               # Formatting (KB/s, MB/s, GB/s)
│   │   │   ├── ThrottleConfig.swift          # Throttling rule model
│   │   │   └── SystemNetworkTotals.swift     # Aggregate system metrics
│   │   ├── Services/
│   │   │   ├── NetworkMonitor.swift          # Live bandwidth sampler & sparkline history
│   │   │   ├── SocketTracker.swift           # PID socket / port discoverer
│   │   │   ├── TrafficShaper.swift           # dnctl / pfctl pipe & anchor coordinator
│   │   │   ├── PrivilegeManager.swift        # Admin execution manager
│   │   │   ├── ProcessInfoService.swift      # App icon & localized name resolver
│   │   │   └── AppIconHelper.swift           # App icon locator & runtime loader
│   │   ├── ViewModels/
│   │   │   └── DashboardViewModel.swift      # State, search, sorting & actions
│   │   └── Views/
│   │       ├── MainDashboardView.swift       # Full dashboard window
│   │       ├── ProcessRowView.swift          # Process item with live speed tags
│   │       ├── ThrottleSheetView.swift       # Slider & numeric speed limit sheet
│   │       ├── SpeedBadgeView.swift          # Colored speed badge (↓ / ↑)
│   │       ├── StatusBarSummaryView.swift    # Global header card with app branding
│   │       └── Components/
│   │           ├── SparklineView.swift       # Real-time mini bandwidth graph
│   │           └── AppIconView.swift         # Dynamic rounded squircle app icon
│   ├── ThrottleNetApp/
│   │   ├── ThrottleNetApp.swift              # App entry point & MenuBarExtra
│   │   └── AppDelegate.swift                 # Lifecycle, Dock icon & cleanup on exit
│   └── ThrottleNetTestsRunner/
│       └── main.swift                        # Automated test suite
└── Scripts/
    ├── build_app.sh                          # Compiles & packages ThrottleNet.app with AppIcon.icns
    └── run.sh                                # Quick launch script
```

---

## 🚀 Quick Start

### 1. Run in Development Mode
To launch the app directly from source:
```bash
./Scripts/run.sh
# or
swift run ThrottleNet
```

### 2. Run Test Suite
To run the automated verification suite:
```bash
swift run ThrottleNetTestsRunner
```

### 3. Build macOS App Bundle (`ThrottleNet.app`)
To build the standalone release application:
```bash
./Scripts/build_app.sh
```
The compiled bundle will be located at:
```
build/ThrottleNet.app
```

---

## 🔒 Privileges & Permissions

Bandwidth throttling uses macOS's built-in `dnctl` and `pfctl` utilities, which require standard administrator privileges. When applying a throttle for the first time, macOS will present a standard administrator prompt to authorize the traffic shaping rule.
