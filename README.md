# Enable Wi-Fi 6GHz & Wi-Fi 7

> Magisk / KernelSU / APatch module — Unlock 6GHz & Wi-Fi 7 (802.11be) on Qualcomm devices

[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)

Fork of [AndroPlus-org/magisk-module-wifi7](https://github.com/AndroPlus-org/magisk-module-wifi7) with:
- Multi-vendor / multi-SKU chip detection (`kiwi_v2` / `peach_v2` / etc.)
- Driver-level full unlock: `BandCapability`, `oem_6g_support_disable`, ETSI SRD SAP channels, indoor-channel patch
- Forced country code (AU) + disabled 802.11d & framework country-code scanning

---

## 中文说明

### 这是什么？

一个 Magisk / KernelSU / APatch 模块，用于在**高通平台**设备上启用 Wi-Fi 6GHz 与 Wi-Fi 7（802.11be）。针对小米 / OPPO / OnePlus / 三星 / 联想等厂商的系统级限制做了解锁。

> ⚠️ **法律与合规提示**：6GHz 频段在许多国家/地区（包括中国大陆）属于受限频段。本模块强制将国家代码设置为 AU（澳大利亚），仅用于**开发 / 测试 / 学习**目的。**请勿在不符合当地无线电法规的环境中使用**。使用本模块造成的任何后果由使用者自行承担。

### 原仓库

本项目基于 AndroPlus 的原始模块分叉：

- **原仓库**: [https://github.com/AndroPlus-org/magisk-module-wifi7](https://github.com/AndroPlus-org/magisk-module-wifi7)
- **原作者**: [AndroPlus](https://github.com/AndroPlus-org)

### 功能

| 功能 | 说明 |
|---|---|
| 6GHz STA 解锁 | 客户端连接 6GHz 网络（5955–7115 MHz 按法规开放的部分） |
| Wi-Fi 7 启用 | `ieee80211be=1`，802.11be / MLD 相关驱动参数 |
| 驱动全解锁 | `BandCapability` 注释（开放全部频段能力）、`oem_6g_support_disable=0` |
| 强制国家代码 AU | 覆盖 framework / telephony / 扫描的国家码更新 |
| 禁用 802.11d | `g11dSupportEnabled=0`，驱动不再通过 802.11d 从 AP 学国家码 |
| 禁用框架国家码扫描 | `config_wifiUpdateCountryCodeFromScanResultGeneric=false` 等资源覆盖 |
| 多厂商支持 | 小米 / OPPO / OnePlus / 三星（persist）/ 联想 / 通用高通 |
| 多 SKU 识别 | 通过 `dumpsys wifi` 读取实际芯片 `HW:` 值（如 `kiwi_v2`、`peach_v2`），避免通配符选错 SKU 目录 |

### 支持设备

- **已验证**: 小米 15（`dada`, SM8750, PEACH_V2）、小米 Pad 6S Pro（`sheng`, SM8550, KIWI_V2）
- **理论支持**: 其他使用高通 WiFi 芯片（WCN6856 / WCN7850 / WCN7750 等）的骁龙设备
- **部分支持**: OPPO / OnePlus（ODM 路径优先）、三星（`/mnt/vendor/persist/wlan` 的 `enable_11be`）、联想

### 安装

1. 下载 [最新 Release](https://github.com/preca-hoshino/enable-wifi-7/releases) 的 `enable-wifi-7-vXX.zip`
2. 在 Magisk / KernelSU / APatch 管理器中刷入
3. **重启**

> KernelSU 用户注意：需要安装 metamodule（如 `meta-overlayfs`）才能挂载 `system/` 目录中的 overlay。模块也内置了 bind mount 兜底（post-fs-data 阶段检测 ini 是否生效，未生效则手动 bind）。

### 验证是否生效

```sh
# 国家代码应为 AU
adb shell cmd wifi get-country-code
# 6GHz STA 可用信道应非空（24 个信道 5955-6415 或更多）
adb shell cmd wifi get-allowed-channel -b 8
# 驱动参数确认（以小米 15 peach_v2 为例）
adb shell grep -E "g11dSupportEnabled|oem_6g_support_disable|gindoor_channel_support" \
  /vendor/etc/wifi/peach_v2/WCNSS_qcom_cfg.ini
```

### 工作原理

1. **安装时**（`customize.sh`）：检测厂商 / SoC / 主板 → 定位芯片对应的 ini 目录 → 应用解锁参数表 → 将解锁后的 ini 放入模块 `system/` overlay 路径
2. **开机时**（`post-fs-data.sh`）：若 overlay 未生效则 bind mount 兜底；用 resetprop 设置 `ro.boot.wificountrycode=AU`
3. **启动后**（`service.sh`）：改写 `WifiConfigStore.xml` 的 country code（CN→AU）、覆盖框架层 `config_wifiUpdateCountryCodeFromScanResultGeneric` 等配置、执行 `cmd wifi force-country-code enabled AU`

### 已知限制

- **6GHz 热点（SAP）**：高通驱动在 SAP / P2P-GO 角色下不开放 6GHz 信道表（`get-allowed-channel` 的 SAP mode 为空），且小米驱动补丁 `gindoor_channel_support` 要求 SAP 使用 6GHz 室内信道时 STA 必须先连接同一室内信道。模块无法绕过驱动固件层的这一限制。**6GHz 热点大概率无法稳定工作**，这是驱动固件行为，不是模块缺陷。
- 6GHz 是否可用最终取决于驱动固件与天线硬件，不同设备差异较大。

### 卸载

直接在 Magisk / KernelSU / APatch 管理器中卸载模块并重启即可。

---

## English

### What is this?

A Magisk / KernelSU / APatch module that enables **Wi-Fi 6GHz & Wi-Fi 7 (802.11be)** on Qualcomm-powered devices, bypassing vendor (Xiaomi / OPPO / OnePlus / Samsung / Lenovo) system-level restrictions.

> ⚠️ **Legal notice**: The 6GHz band is restricted in many countries/regions (including mainland China). This module forces the country code to AU (Australia) for **development / testing / educational purposes only**. **Do not use it where it violates local radio regulations.** Use at your own risk.

### Upstream

This project is a fork of AndroPlus's original module:

- **Upstream repo**: [https://github.com/AndroPlus-org/magisk-module-wifi7](https://github.com/AndroPlus-org/magisk-module-wifi7)
- **Upstream author**: [AndroPlus](https://github.com/AndroPlus-org)

### Features

| Feature | Description |
|---|---|
| 6GHz STA unlock | Connect to 6GHz networks |
| Wi-Fi 7 enable | `ieee80211be=1` + MLD driver params |
| Driver full unlock | `BandCapability` commented out, `oem_6g_support_disable=0` |
| Force country AU | Overrides framework / telephony / scan updates |
| Disable 802.11d | `g11dSupportEnabled=0` |
| Disable framework CC scan | Overlay: `config_wifiUpdateCountryCodeFromScanResultGeneric=false` |
| Multi-vendor | Xiaomi / OPPO / OnePlus / Samsung (persist) / Lenovo / generic QC |
| Multi-SKU detection | Reads actual chip `HW:` from `dumpsys wifi` (e.g. `kiwi_v2`, `peach_v2`) |

### Installation

1. Download the latest `enable-wifi-7-vXX.zip` from [Releases](https://github.com/preca-hoshino/enable-wifi-7/releases)
2. Flash it in Magisk / KernelSU / APatch manager
3. **Reboot**

> KernelSU users need a metamodule (e.g. `meta-overlayfs`) for `system/` overlay mounting. The module also ships a bind-mount fallback in `post-fs-data.sh`.

### Verify

```sh
# Country code should be AU
adb shell cmd wifi get-country-code
# 6GHz STA channels should be non-empty
adb shell cmd wifi get-allowed-channel -b 8
# Driver ini parameters (example: Xiaomi 15 peach_v2)
adb shell grep -E "g11dSupportEnabled|oem_6g_support_disable|gindoor_channel_support" \
  /vendor/etc/wifi/peach_v2/WCNSS_qcom_cfg.ini
```

### Known limitations

- **6GHz hotspot (SAP)**: Qualcomm drivers do not expose any 6GHz channels in SAP / P2P-GO mode (`get-allowed-channel` SAP mode is empty), and Xiaomi's driver patch `gindoor_channel_support` requires the STA to be connected to the same indoor channel before SAP can use it. This is a driver/firmware-level constraint the module cannot bypass. **6GHz hotspot most likely will not work reliably.**
- Actual 6GHz availability depends on driver firmware and antenna hardware; results vary by device.

### Uninstall

Remove the module in the manager and reboot.

---

## License

[GNU Affero General Public License v3.0](LICENSE) — © preca-hoshino

Portions derived from [AndroPlus-org/magisk-module-wifi7](https://github.com/AndroPlus-org/magisk-module-wifi7) © AndroPlus.
