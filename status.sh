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

# ---------- 等待 wifi 就绪 (开机时驱动可能未加载完) ----------
# 最多等 120 秒: 每 5 秒检查一次 country code 是否返回有效值
WAIT=0
while [ $WAIT -lt 24 ]; do
    CC_RAW=$(cmd wifi get-country-code 2>/dev/null)
    CC_TMP=$(printf '%s' "$CC_RAW" | grep -o '= *[A-Za-z]*' | tr -d '= ' | head -1)
    if [ -n "$CC_TMP" ] && [ "$CC_TMP" != "n/a" ]; then
        break
    fi
    sleep 5
    WAIT=$((WAIT + 1))
done

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
CH_LIST_STR="n/a"   # STA 信道列表 (逗号分隔)
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
    # 完整信道列表 (逗号分隔)
    if [ "$STA6" != "n/a" ] && [ "$STA6" -gt 0 ] 2>/dev/null; then
        CH_LIST_STR=$(printf '%s' "$STA_SEG" | grep -oE '[0-9]{4}' | tr '\n' ',' | sed 's/,$//')
    fi
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

# ---------- 组装描述 (色球状态标识, | 分隔) ----------
# 参数表 (每项 = 字段 + 状态 + 颜色小球):
#   CC       国家码      AU=🟢 / 其他=🔴 / 未知=⚪
#   wifi     开关        on=🟢 / off=🟡
#   6G-STA   STA 信道    >0=🟢(Nch) / 0=🔴blocked / 未知=⚪
#   6G-SAP   SAP 信道    >0=🟢(Nch) / 0=🟡driver-limit / 未知=⚪
#   11be     802.11be    on=🟢 / off=🔴 / 未知=⚪
#   drv      驱动 ini    unlocked=🟢 / 其他=🔴
# 全字段恒定显示 (wifi off 时 6G 段显示 n/a), 便于对齐阅读

# 1. 国家码
case "$CC" in
    AU)  CC_ICON="🟢" ;;
    n/a) CC_ICON="⚪" ;;
    *)   CC_ICON="🔴" ;;
esac

# 2. WiFi 开关
case "$WIFI_STATE" in
    on)  WIFI_ICON="🟢" ;;
    *)   WIFI_ICON="🟡" ;;
esac

# 3. 6GHz STA / SAP
STA_ICON="⚪"; STA_TXT="n/a"
SAP_ICON="⚪"; SAP_TXT="n/a"
if [ "$WIFI_STATE" = "on" ]; then
    if [ "$STA6" != "n/a" ] && [ "$STA6" -gt 0 ] 2>/dev/null; then
        STA_ICON="🟢"; STA_TXT="${STA6}ch"
    else
        STA_ICON="🔴"; STA_TXT="blocked"
    fi
    if [ "$SAP6" != "n/a" ] && [ "$SAP6" -gt 0 ] 2>/dev/null; then
        SAP_ICON="🟢"; SAP_TXT="${SAP6}ch"
    else
        SAP_ICON="🟡"; SAP_TXT="driver-limit"
    fi
fi

# 4. 802.11be
case "$BE11" in
    on)  BE_ICON="🟢" ;;
    off) BE_ICON="🔴" ;;
    *)   BE_ICON="⚪" ;;
esac

# 5. 驱动 ini
case "$INI_ST" in
    unlocked) DRV_ICON="🟢" ;;
    *)        DRV_ICON="🔴" ;;
esac

# 组装 (| 分隔, 全字段恒定)
DESC="[wifi7] ${CC_ICON}CC:${CC}"
DESC="${DESC} | ${WIFI_ICON}wifi:${WIFI_STATE}"
if [ "$WIFI_STATE" = "on" ]; then
    DESC="${DESC} | ${STA_ICON}6G-STA:${STA_TXT}"
    DESC="${DESC} | ${SAP_ICON}6G-SAP:${SAP_TXT}"
else
    DESC="${DESC} | ⚪6G-STA:n/a | ⚪6G-SAP:n/a"
fi
DESC="${DESC} | ${BE_ICON}11be:${BE11}"
DESC="${DESC} | ${DRV_ICON}drv:${INI_ST}"

# 信道编号详情: 第二行换行, 括号括起, 逗号分隔
if [ "$STA6" != "n/a" ] && [ "$STA6" -gt 0 ] 2>/dev/null; then
    DESC="${DESC}
STA ch: (${CH_LIST_STR})"
fi

# 单行版本 (module.prop 写入用: key=value 格式不支持换行, 换行替换为空格)
DESC_SINGLE=$(printf '%s' "$DESC" | tr '\n' ' ')

# ---------- 写入 ----------
# 参考 AdGuardHomeForRoot / Specter 等成熟 KSU 模块的写法:
#   1) 直接改写 module.prop 的 description 行 (Magisk/MMRL/KSU Manager 都读它)
#   2) 再用 ksud module config set override.description (KSU 官方动态描述 API)
#   - 环境变量兼容: KSU 脚本运行时注入 KSU_MODULE; 手动执行时用 MODULE_ID 前缀
#   - 用绝对路径 /data/adb/ksud, 避免 PATH 不含 ksu/bin
#
# 多行处理: module.prop 是行式 key=value 解析, description 含换行会破坏后续行
#           → module.prop 写单行版 DESC_SINGLE (信道列表在行内空格分隔)
#           → ksud override.description 写完整多行版 DESC (KSU 官方支持多行值)
#
# 定时轮询优化: 状态未变化时跳过写入 (service.sh 每 5 秒调用, 避免无谓 IO)

LAST_FILE="$MODDIR/.status_last"
if [ -f "$LAST_FILE" ] && [ "$(cat "$LAST_FILE" 2>/dev/null)" = "$DESC" ]; then
    # 状态未变, 跳过写入
    exit 0
fi

# 1. sed 兜底: 改 module.prop (单行版, 先转义 sed 特殊字符)
MP="$MODDIR/module.prop"
if [ -f "$MP" ]; then
    ESCAPED=$(printf '%s' "$DESC_SINGLE" | sed 's|[#&\\]|\\&|g')
    sed -i "s#^description=.*#description=$ESCAPED#" "$MP" 2>/dev/null
fi

# 2. KernelSU 官方动态描述 API (完整多行版)
if [ -x /data/adb/ksud ]; then
    if [ -n "$KSU_MODULE" ]; then
        /data/adb/ksud module config set override.description "$DESC" 2>/dev/null
    elif [ -n "$MODULE_ID" ]; then
        KSU_MODULE="$MODULE_ID" /data/adb/ksud module config set override.description "$DESC" 2>/dev/null
    else
        KSU_MODULE="$MODID" /data/adb/ksud module config set override.description "$DESC" 2>/dev/null
    fi
fi

# 3. 记录当前描述 (供下次轮询比对)
printf '%s' "$DESC" > "$LAST_FILE" 2>/dev/null

echo "$DESC"
