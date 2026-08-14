# Changelog

## v14 (2026-08-15)

- **动态描述格式更新**: 字段间用 `|` 分隔，新增第二行信道编号详情
  - 完整版 (KSU): `[wifi7] 🟢CC:AU | 🟢wifi:on | 🟢6G-STA:24ch | 🟡6G-SAP:driver-limit | 🟢11be:on | 🟢drv:unlocked` 换行 `STA ch: (5955,5975,...6415)`
  - 单行版 (Magisk/MMRL): 信道列表折叠进单行，兼容行式 module.prop 解析
  - 全字段恒定显示，wifi off 时 6G 段显示 `⚪6G-STA:n/a`
- **新增功能: 关闭 WLAN 扫描调节** (`wifi_scan_throttle_enabled=0`)
  - 某些应用检测到"WLAN扫描调节已启用"会提示；模块开机时自动关闭，应用不再受限扫描频率
  - 仅开机时设置一次，不覆盖用户手动修改
- **定时刷新**: service.sh 每 5 秒调用 status.sh，状态变化时才写入（内部去重，避免无谓 IO）

## v13 (2026-08-15)

- **修复动态描述开机不刷新的根因**: `service.sh` 丢失了 `MODDIR=${0%/*}` 定义，导致开机时 `sh "${MODDIR}/status.sh"` 变成 `sh "/status.sh"`（文件不存在，静默失败），描述永不刷新
  - 对比 `post-fs-data.sh` 一直有该定义，`service.sh` 在 v05 修改时被误删
  - 已模拟 KSU 执行方式实测: 修复后 service.sh 能正确调用 status.sh，描述自动更新为色球动态版
- `status.sh` 增加等待重试: 开机时若 wifi 未就绪（country code 无值），每 5 秒重试，最多等 120 秒，确保写入有效状态而非垃圾值

## v12 (2026-08-15)

- **参数保守化，降低 boot 卡死风险**（Xiaomi 15 实测卡第二屏后修复）
  - `customize.sh`: 解锁参数表精简为仅 `oem_6g_support_disable=0`（6GHz 总开关），移除 `etsi13_srd_chan_in_master_mode=7` 与 `gindoor_channel_support=1`
  - 原因: 这两个参数只影响 SAP/P2P-GO 角色，而驱动在 SAP 下本就不开放 6GHz 信道；强制它们会让驱动尝试未预期的信道组合，曾导致驱动固件忙等 → QCOM watchdog 25s 强制重启（卡第二屏）
  - 现保留 SAP 参数出厂原值（不强制、不追加），仅做 STA 6GHz 解锁
- `system.prop`: 移除冗余的 `ro.boot.countrycode=us`（Lenovo 已不需要，post-fs-data.sh 已 resetprop `ro.boot.wificountrycode=AU`）
- **bootloop 防护不内置**: 救砖由 KernelSU safe mode（音量减开机）负责

## v11 (2026-08-15)

- **动态描述改为色球状态标识**: 每项状态前用 🟢(正常/已解锁) 🟡(中间/驱动受限) 🔴(异常/未解锁) ⚪(未知) 标识
  - 例: `[wifi7] 🟢CC:AU 🟢wifi:on 🟢6G-STA:24ch 🟡6G-SAP:driver-limit 🟢11be:on 🟢drv:unlocked`
- **去掉默认描述**: 描述仅包含动态状态, 不再附带功能说明尾缀; `module.prop` 静态描述精简为一行

## v10 (2026-08-15)

- **精简 system.prop，降低副作用**: 移除 `ro.product.locale.region=US` 与 `ro.product.countrycode=us`（这两个属性会改变系统区域，影响 Play 商店/应用市场区域，且与国家码解锁无关）
- 保留: `ro.miui.wifi.region=US`（小米 6GHz 频段）、`ro.boot.countrycode=us`（联想）、`ro.boot.wificountrycode=AU`、`ro.oplus.wifi.11be_disabled=0`
- 安全评估结论: 模块无 framework 级修改、无阻塞 boot 的操作，卡第二屏风险低

## v09 (2026-08-15)

- **修复动态状态描述未生效**（参考 AdGuardHomeForRoot / Specter 等成熟 KSU 模块的写法）
  - 写入逻辑改为: 先 `sed` 直接改写 `module.prop` 的 description 行（Magisk/MMRL/KSU Manager 都读取，最可靠），再用 `ksud module config set override.description`（KSU 官方 API）
  - 不再依赖 `/data/local/tmp` 临时文件（开机时 `u:r:ksu:s0` 上下文可能无写权限，导致旧版 awk 方案静默失败）
  - ksud 改用绝对路径 `/data/adb/ksud`，避免 PATH 缺失
  - 环境变量兼容 `KSU_MODULE`（KSU 脚本注入）与 `MODULE_ID`
- **注意**: `service.sh` 仅在开机时执行一次，安装模块后需**重启**才能自动刷新描述；也可手动运行 `sh /data/adb/modules/enable-wifi-7/status.sh`

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
