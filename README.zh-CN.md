# 启用 Wi-Fi 6GHz 与 Wi-Fi 7

一个 Magisk / KernelSU / APatch 模块，用于在高通平台的 Android 设备上启用 Wi-Fi 6GHz 与 Wi-Fi 7（802.11be）。

本项目是 [AndroPlus-org/magisk-module-wifi7](https://github.com/AndroPlus-org/magisk-module-wifi7) 的分支，增加了设备识别与驱动级解锁逻辑。英文文档见 [README.md](README.md)。

## 概述

厂商通常在多个层面限制 6GHz 与 Wi-Fi 7 功能：驱动配置（`WCNSS_qcom_cfg.ini`）、框架国家代码处理以及区域信道表。本模块针对高通平台处理这些层面：

- 在安装时定位芯片对应的驱动配置并应用解锁参数。
- 开机时将 WiFi 国家代码强制为 AU，覆盖框架与运营商更新。
- 禁用 802.11d 与框架国家代码扫描，防止国家代码被改回。

## 功能

- 启用 6GHz STA 连接（信道可用性取决于法规信道表与硬件）。
- 启用 Wi-Fi 7（802.11be）参数，包括 MLD。
- 驱动级解锁：`BandCapability`、`oem_6g_support_disable`、ETSI SRD SAP 信道、室内信道支持。
- 强制国家代码 AU：通过 `resetprop`、改写 `WifiConfigStore.xml` 及 `cmd wifi force-country-code` 实现。
- 禁用 802.11d（`g11dSupportEnabled=0`）及框架国家代码扫描/回退。
- 多厂商识别：小米、OPPO、OnePlus、三星（persist）、联想及通用高通设备。
- 多 SKU 芯片识别：从 `dumpsys wifi` 读取实际芯片名称（如 `kiwi_v2`、`peach_v2`），对正确的 SKU 目录打补丁，而非依赖通配符猜测。
- 动态状态显示：开机时自动将实时解锁状态（国家代码、6GHz STA/SAP 信道数、802.11be、驱动 ini 状态）写入模块描述，KernelSU Manager 与 MMRL 等支持动态描述的加载器可显示。

## 环境要求

- Magisk 20.4+ / KernelSU / APatch
- 支持 6GHz 的高通 WiFi 芯片（如 WCN6856、WCN7850、WCN7750）
- KernelSU 用户需额外安装 metamodule（如 `meta-overlayfs`）以挂载 `system/` 目录 overlay；模块内置 bind mount 兜底。

## 安装

1. 从 [Releases](https://github.com/preca-hoshino/enable-wifi-7/releases) 页面下载最新的 `enable-wifi-7-vXX.zip`。
2. 在 Magisk / KernelSU / APatch 中刷入该 zip。
3. 重启。

卸载：在管理器中移除模块并重启即可。

## 验证

```sh
# 国家代码应为 AU
adb shell cmd wifi get-country-code

# 6GHz STA 可用信道应非空
adb shell cmd wifi get-allowed-channel -b 8

# 驱动参数确认（以小米 15 peach_v2 为例）
adb shell grep -E "g11dSupportEnabled|oem_6g_support_disable|gindoor_channel_support" \
  /vendor/etc/wifi/peach_v2/WCNSS_qcom_cfg.ini
```

## 工作原理

1. **安装时**（`customize.sh`）：检测厂商 / SoC / 主板，定位芯片对应的 ini 目录，应用解锁参数表，并将补丁后的 ini 放入模块 `system/` overlay 路径。
2. **开机时**（`post-fs-data.sh`）：若 overlay 未生效则 bind mount 兜底；通过 `resetprop` 设置 `ro.boot.wificountrycode=AU`。
3. **启动完成后**（`service.sh`）：改写 `WifiConfigStore.xml` 中的国家代码（CN 至 AU）、覆盖框架扫描配置，并执行 `cmd wifi force-country-code enabled AU`。
4. **状态上报**（`status.sh`）：检测实时解锁状态（国家代码、6GHz STA/SAP 信道数、802.11be、驱动 ini）并写入模块描述；KernelSU 通过 `ksud module config set override.description`，Magisk/MMRL 通过改写 `module.prop`。也可手动刷新：`sh /data/adb/modules/enable-wifi-7/status.sh`。

## 兼容性

已在以下设备验证：

- 小米 15（`dada`，SM8750，PEACH_V2）
- 小米 Pad 6S Pro（`sheng`，SM8550，KIWI_V2）

其他使用类似高通 WiFi 芯片的设备预期可用，但未经验证。

## 已知限制

- **6GHz 热点（SAP）**：高通驱动在 SAP / P2P-GO 角色下不开放 6GHz 信道（`get-allowed-channel` 报告的 SAP 信道列表为空），且小米驱动补丁 `gindoor_channel_support` 要求 STA 先连接同一室内信道，SAP 才能使用该信道。这是驱动/固件层面的限制，模块无法绕过。因此 6GHz 热点无法保证稳定工作。
- 6GHz 可用性最终取决于驱动固件与天线硬件，不同设备差异较大。

## 法律声明

6GHz 频段在许多国家和地区（包括中国大陆）属于受限频段。本模块将国家代码强制为 AU（澳大利亚），仅用于开发、测试与学习目的。请勿在违反当地无线电法规的环境中使用。使用风险自负。

## 上游

- 仓库：[AndroPlus-org/magisk-module-wifi7](https://github.com/AndroPlus-org/magisk-module-wifi7)
- 作者：[AndroPlus](https://github.com/AndroPlus-org)

## 许可

[GNU Affero General Public License v3.0](LICENSE) - 版权所有 (c) 2026 preca-hoshino

部分内容衍生自 [AndroPlus-org/magisk-module-wifi7](https://github.com/AndroPlus-org/magisk-module-wifi7)，版权所有 (c) AndroPlus。
