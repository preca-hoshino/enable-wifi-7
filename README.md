# Enable Wi-Fi 6GHz & Wi-Fi 7

A Magisk / KernelSU / APatch module that enables Wi-Fi 6GHz and Wi-Fi 7 (802.11be) on Qualcomm-based Android devices.

This is a fork of [AndroPlus-org/magisk-module-wifi7](https://github.com/AndroPlus-org/magisk-module-wifi7) with additional device detection and driver-level unlock logic. Chinese documentation is available in [README.zh-CN.md](README.zh-CN.md).

## Overview

Vendors restrict 6GHz and Wi-Fi 7 functionality at several layers: driver configuration (`WCNSS_qcom_cfg.ini`), framework country-code handling, and regional channel tables. This module addresses those layers on Qualcomm platforms:

- Locates the chip-specific driver configuration and applies unlock parameters at install time.
- Forces the WiFi country code to AU at boot, overriding framework and telephony updates.
- Disables 802.11d and framework country-code scanning to prevent the code from being reverted.

## Features

- Enables 6GHz STA operation (channel availability depends on regulatory tables and hardware).
- Enables Wi-Fi 7 (802.11be) parameters, including MLD.
- Driver-level unlock: `BandCapability`, `oem_6g_support_disable`, ETSI SRD SAP channels, indoor-channel support.
- Forced country code (AU) via `resetprop`, `WifiConfigStore.xml` rewrite, and `cmd wifi force-country-code`.
- Disables 802.11d (`g11dSupportEnabled=0`) and framework country-code scan/fallback.
- Multi-vendor detection: Xiaomi, OPPO, OnePlus, Samsung (persist), Lenovo, and generic Qualcomm.
- Multi-SKU chip detection: reads the actual chip name (e.g. `kiwi_v2`, `peach_v2`) from `dumpsys wifi`, so the correct SKU directory is patched instead of a wildcard guess.
- Dynamic status in module description: the module description is updated at boot with live unlock state (country code, 6GHz STA/SAP channel counts, 802.11be, driver ini status). Supported by KernelSU Manager and MMRL.

## Requirements

- Magisk 20.4+ / KernelSU / APatch
- A Qualcomm device with a 6GHz-capable WiFi chip (e.g. WCN6856, WCN7850, WCN7750)
- KernelSU users additionally need a metamodule (such as `meta-overlayfs`) for `system/` overlay mounting. A bind-mount fallback is included.

## Installation

1. Download the latest `enable-wifi-7-vXX.zip` from the [Releases](https://github.com/preca-hoshino/enable-wifi-7/releases) page.
2. Flash the zip in Magisk / KernelSU / APatch.
3. **Reboot** — the status description is refreshed by `service.sh` at boot. To refresh without rebooting: `sh /data/adb/modules/enable-wifi-7/status.sh`.

To uninstall, remove the module in the manager and reboot.

## Verification

```sh
# Country code should be AU
adb shell cmd wifi get-country-code

# 6GHz STA channels should be non-empty
adb shell cmd wifi get-allowed-channel -b 8

# Driver parameters (example: Xiaomi 15, peach_v2)
adb shell grep -E "g11dSupportEnabled|oem_6g_support_disable|gindoor_channel_support" \
  /vendor/etc/wifi/peach_v2/WCNSS_qcom_cfg.ini
```

## How It Works

1. **Install time** (`customize.sh`): detects vendor / SoC / board, locates the chip-specific ini directory, applies the unlock parameter table, and places the patched ini in the module's `system/` overlay path.
2. **Boot** (`post-fs-data.sh`): bind-mounts the patched ini if the overlay did not take effect; sets `ro.boot.wificountrycode=AU` via `resetprop`.
3. **Post-boot** (`service.sh`): rewrites the country code in `WifiConfigStore.xml` (CN to AU), overrides framework scan configs, and runs `cmd wifi force-country-code enabled AU`.
4. **Status reporting** (`status.sh`): detects and writes the live unlock state (country code, 6GHz STA/SAP channels, 802.11be, driver ini) into the module description — first via a direct `module.prop` rewrite (works on all loaders), then via `ksud module config set override.description` on KernelSU. Runs at boot from `service.sh`; refresh manually with `sh /data/adb/modules/enable-wifi-7/status.sh`.

## Compatibility

Verified on:

- Xiaomi 15 (`dada`, SM8750, PEACH_V2)
- Xiaomi Pad 6S Pro (`sheng`, SM8550, KIWI_V2)

Other devices with similar Qualcomm WiFi chips are expected to work but are not verified.

## Known Limitations

- **6GHz hotspot (SAP)**: Qualcomm drivers do not expose 6GHz channels in SAP / P2P-GO mode (the SAP channel list reported by `get-allowed-channel` is empty), and Xiaomi's driver patch `gindoor_channel_support` requires the STA to be connected to the same indoor channel before SAP can use it. This is a driver/firmware constraint that the module cannot bypass. Reliable 6GHz hotspot operation is therefore not expected.
- 6GHz availability ultimately depends on driver firmware and antenna hardware; results vary by device.

## Legal Notice

The 6GHz band is restricted in many countries and regions (including mainland China). This module forces the country code to AU (Australia) and is intended for development, testing, and educational purposes only. Do not use it in environments where it violates local radio regulations. Use at your own risk.

## Upstream

- Repository: [AndroPlus-org/magisk-module-wifi7](https://github.com/AndroPlus-org/magisk-module-wifi7)
- Author: [AndroPlus](https://github.com/AndroPlus-org)

## License

[GNU Affero General Public License v3.0](LICENSE) - Copyright (c) 2026 preca-hoshino

Portions derived from [AndroPlus-org/magisk-module-wifi7](https://github.com/AndroPlus-org/magisk-module-wifi7), Copyright (c) AndroPlus.
