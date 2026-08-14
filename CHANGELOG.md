# Changelog

## v08 (2026-08-15)

- **动态状态描述**: 新增 `status.sh`，开机后自动检测解锁状态并写入模块描述，KernelSU Manager / MMRL 等支持动态描述的加载器可实时显示
  - 检测内容: 国家代码 (CC)、WiFi 开关、6GHz STA 信道数、6GHz SAP 信道数、802.11be、驱动 ini 解锁状态
  - 机制: KernelSU 用 `ksud module config set override.description`，Magisk/MMRL 改写 `module.prop` 的 description 行
  - 手动刷新: `sh /data/adb/modules/enable-wifi-7/status.sh`

## v06 (2026-08-14)

- **Driver full unlock**: 参数表覆盖 `BandCapability`（注释）、`oem_6g_support_disable=0`、ETSI SRD SAP 信道（`etsi13_srd_chan_in_master_mode=7`）、室内信道补丁（`gindoor_channel_support=1`，存在则强制、缺失则追加）
- **多 SKU 芯片识别**: 通过 `dumpsys wifi` 读取 `HW:` 实际芯片名（如 `kiwi_v2` / `peach_v2`），按芯片目录精确匹配 ini，避免通配符选错受限 SKU
- **多厂商支持**: 高通（小米/OPPO/OnePlus/三星/联想/通用）、三星 persist（`enable_11be`）、联发科（仅国家码）
- **国家代码 AU**: `ro.boot.wificountrycode=AU` resetprop + `cmd wifi force-country-code enabled AU` + `WifiConfigStore.xml` CN→AU 改写 + 框架扫描回退禁用
- 修复: 覆盖 OPPO odm-first 与 vendor-first 两种候选路径；ini 缺失参数追加到 `END` 标记之前

## v05

- 增强国家代码持久化（`WifiConfigStore.xml` sed 改写 + 权限/SEContext 修复）
- 多 root 方案 resetprop 路径检测（KSU / APatch / Magisk）

## v04

- 框架层禁用国家码扫描/回退（`config_wifiUpdateCountryCodeFromScanResultGeneric` / `config_wifi_revert_country_code_on_cellular_loss`）

## v03

- 安装时 ini 解锁逻辑重构，多厂商检测

## v02

- 适配更多厂商（三星 persist 等）

## v01

- 初始版本（AndroPlus 上游）
