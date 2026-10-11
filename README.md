# POX PROJECT - Toolbox

[![Build and Package APK](https://github.com/POX-project/toolbox/actions/workflows/build.yml/badge.svg)](https://github.com/POX-project/toolbox/actions/workflows/build.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/POX-project/toolbox?color=brightgreen)](https://github.com/POX-project/toolbox/releases)

**Maintainer:** **`txorav`** • **Platform:** Android 8.0+ / Cross-Platform (Flutter)

A comprehensive Android system utilities, hardware diagnostics, and device management suite designed for custom ROMs, kernels, and everyday power users.

---

## 🌟 Modules & Features

### 📊 1. Device Info & Hardware Telemetry
* Real-time CPU core frequencies, governor status, and per-cluster load.
* Deep memory analysis: Physical RAM, ZRAM algorithm, swap metrics, and cache levels.
* Battery health telemetry: Charging voltage, microamp current, temperature curves, and cycle counts.
* UFS / eMMC storage breakdown with mount point inspection.

### 🩺 2. Hardware Diagnostics & Component Health
* Interactive display touchscreen multi-touch grid test, dead pixel checker, and refresh rate monitor.
* Sensor audit: Accelerometer, Gyroscope, Magnetometer, Barometer, Proximity, and Ambient Light.
* Thermal zone live monitoring across SoC clusters, battery, and PMIC sensors.
* Speaker, earpiece, and vibration motor haptic test suites.

### 🛠️ 3. Power Tools & Management Utilities
* **Partition Manager**: Inspect partition layout, GPT sector bounds, dm-linear super partitions, and filesystem mount types.
* **Task Manager**: Inspect running processes, Linux memory RSS, nice values, and PID tree.
* **ADB & Fastboot Bridge**: Native Android shell command runner and diagnostics terminal.
* **File & Archive Tools**: High-speed archive extraction, XAPK / split APK multi-package installer.

### 🎨 4. Design & Customization
* Full Material 3 and adaptive glassmorphism design system.
* Dynamic theme switching: High-contrast Dark, Light, and AMOLED black modes.
* Powered by Flutter & Riverpod state management.

---

## 🛠️ Building

To build the APK locally using Flutter:

```bash
flutter pub get
flutter build apk --release
```

The output APK will be placed in `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📥 Installation

Download the latest `toolbox-*.apk` from [GitHub Releases](https://github.com/POX-project/toolbox/releases) and install via:

```bash
adb install -r toolbox.apk
```

---

## 🇵🇸 Solidarity
**FREE PALESTINE** — Support justice, end oppression, and spread awareness on all matters of shared humanity.
