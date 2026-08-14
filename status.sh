#!/system/bin/sh
# Enable Wi-Fi 6GHz & Wi-Fi 7 - 动态状态描述
# Fork of https://github.com/AndroPlus-org/magisk-module-wifi7 (© AndroPlus)
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# 用途: 检测模块解锁状态并写入模块描述, 在支持动态描述的模块加载器
#       (KernelSU Manager / MMRL 等) 的模块列表页显示关键信息。
# 机制:
#   - KernelSU: ksud module config set override.description "..."
#   - Magisk / MMRL: 直接改写 /data/adb/modules/<id>/module.prop 的 description 行
#
# 可手动刷新: sh /data/adb/modules/enable-wifi-7/status.sh

MODDIR=${0%/*}
MODID=$(grep '^id=' "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2)
[ -z "$MODID" ] && MODID=enable-wifi-7

# ---------- 状态检测 (全部容错, 失败显示 n/a) ----------

# 1. 国家代码
CC="n/a"
CC_RAW=$(cmd wifi get-country-code 2>/dev/null)
CC=$(printf '%s' "$CC_RAW" | grep -o '= *[A-Za-z]*' | tr -d '= ' | head -1)

# 2. WiFi 开关状态
WIFI_STATE="off"
cmd wifi status 2>/dev/null | grep -q "Wifi is enabled" && WIFI_STATE="on"

# 3. 6GHz STA 信道数 (band 8 = 6GHz)
STA6="n/a"
SAP6="n/a"
if [ "$WIFI_STATE" = "on" ]; then
    CH_LIST=$(cmd wifi get-allowed-channel -b 8 2>/dev/null)
    # 信道号是 4 位数字 (5955-7115), 按数字出现次数统计
    STA_SEG=$(printf '%s' "$CH_LIST" | sed -n '/Allowed ch in STA mode:/,/Allowed ch in SAP mode:/p')
    SAP_SEG=$(printf '%s' "$CH_LIST" | sed -n '/Allowed ch in SAP mode:/,/Allowed ch in WiFi-Direct GC mode:/p')
    [ -z "$SAP_SEG" ] && SAP_SEG=$(printf '%s' "$CH_LIST" | sed -n '/Allowed ch in SAP mode:/,$p')
    STA6=$(printf '%s' "$STA_SEG" | grep -oE '[0-9]{4}' | wc -l)
    SAP6=$(printf '%s' "$SAP_SEG" | grep -oE '[0-9]{4}' | wc -l)
    [ -z "$STA6" ] && STA6="n/a"
    [ -z "$SAP6" ] && SAP6="n/a"
fi

# 4. 802.11be (SoftAp 配置中 Ieee80211beEnabled = true/false)
BE11="n/a"
dumpsys wifi 2>/dev/null | grep -q "Ieee80211beEnabled *= *true" && BE11="on"
dumpsys wifi 2>/dev/null | grep -q "Ieee80211beEnabled *= *false" && BE11="off"

# 5. 驱动 ini 解锁状态 (芯片目录 + 关键参数)
INI_ST="n/a"
CHIP=$(dumpsys wifi 2>/dev/null | grep -o 'HW:[A-Za-z0-9_]*' | head -1 | cut -d: -f2 | tr '[:upper:]' '[:lower:]')
for ini in /vendor/etc/wifi/${CHIP}/WCNSS_qcom_cfg.ini \
           /odm/vendor/etc/wifi/${CHIP}/WCNSS_qcom_cfg.ini \
           /vendor/etc/wifi/WCNSS_qcom_cfg.ini \
           /odm/vendor/etc/wifi/WCNSS_qcom_cfg.ini; do
    if [ -f "$ini" ] && grep -q 'enable-wifi-7 module' "$ini" 2>/dev/null; then
        INI_ST="unlocked"
        break
    fi
done

# ---------- 组装描述 ----------
DESC="[wifi7] CC:${CC} wifi:${WIFI_STATE}"
if [ "$WIFI_STATE" = "on" ]; then
    if [ "$STA6" != "n/a" ] && [ "$STA6" -gt 0 ] 2>/dev/null; then
        DESC="${DESC} 6GHz-STA:${STA6}ch"
    else
        DESC="${DESC} 6GHz-STA:blocked"
    fi
    if [ "$SAP6" != "n/a" ] && [ "$SAP6" -gt 0 ] 2>/dev/null; then
        DESC="${DESC} 6GHz-SAP:${SAP6}ch"
    else
        DESC="${DESC} 6GHz-SAP:driver-limited"
    fi
fi
DESC="${DESC} 11be:${BE11} driver:${INI_ST}"

# 附带简短功能说明 (manager 列表页显示)
DESC="${DESC} | Unlock Wi-Fi 6GHz & Wi-Fi 7 on Qualcomm. Fork of AndroPlus-org/magisk-module-wifi7. AGPL-3.0."

# ---------- 写入 ----------
if command -v ksud >/dev/null 2>&1 && [ -n "$KSU_MODULE" ]; then
    # KernelSU: 官方动态描述机制 (KSU_MODULE 由模块脚本环境注入)
    ksud module config set override.description "$DESC" 2>/dev/null
elif command -v ksud >/dev/null 2>&1; then
    # 手动执行时 KSU_MODULE 未注入, 显式指定
    KSU_MODULE="$MODID" ksud module config set override.description "$DESC" 2>/dev/null
fi

# Magisk / MMRL 兼容: 改写 module.prop 的 description 行 (KSU 下亦可作为兜底)
MP="$MODDIR/module.prop"
if [ -f "$MP" ]; then
    # awk 改写避免 sed 分隔符/& 转义问题; 临时文件避免破坏 mount 关联
    awk -v d="$DESC" 'BEGIN{FS=OFS="="} /^description=/{print "description=" d; next} {print}' "$MP" \
        > /data/local/tmp/wifi7_mp.tmp 2>/dev/null
    [ -s /data/local/tmp/wifi7_mp.tmp ] && cp /data/local/tmp/wifi7_mp.tmp "$MP"
    rm -f /data/local/tmp/wifi7_mp.tmp
fi

echo "$DESC"
