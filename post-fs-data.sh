#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future
MODDIR=${0%/*}
# This script will be executed in post-fs-data mode

WIFICFG="WCNSS_qcom_cfg.ini"

# 1. 优先依赖 KSU/Magisk 的 system/ 目录 overlay 挂载（customize.sh 已把 ini 放入模块 system/ 下）
#    仅当 overlay 未生效（目标文件不含模块标记）时，bind mount fallback
if [ -f "${MODDIR}/xml/wificfg_source" ]; then
    WIFICFG_SRC=$(cat "${MODDIR}/xml/wificfg_source")
    if [ -f "${WIFICFG_SRC}" ] && ! grep -q 'enable-wifi-7 module' "${WIFICFG_SRC}" 2>/dev/null; then
        # overlay 未生效（如 Magisk 未挂载 /vendor 场景）→ bind mount 兜底
        mount -o ro,bind "${MODDIR}/xml/${WIFICFG}" "${WIFICFG_SRC}"
    fi
fi

# 1b. /odm/firmware 固件 ini：驱动固件实际加载的配置（ueventd firmware 机制）
#     KSU/Magisk 的 system/odm overlay 未生效时 → bind mount 兜底
if [ -f "${MODDIR}/xml/wificfg_source_odm" ]; then
    ODM_INI=$(cat "${MODDIR}/xml/wificfg_source_odm")
    if [ -f "${ODM_INI}" ] && ! grep -q 'enable-wifi-7 module' "${ODM_INI}" 2>/dev/null; then
        mount -o ro,bind "${MODDIR}/xml/${WIFICFG}.odm" "${ODM_INI}"
    fi
fi

# 2. 国家代码：多 root 方案兼容的 resetprop 路径
RESETPROP=resetprop
if [ -x /data/adb/ksu/bin/resetprop ]; then
    RESETPROP=/data/adb/ksu/bin/resetprop
elif [ -x /data/adb/ap/bin/resetprop ]; then
    RESETPROP=/data/adb/ap/bin/resetprop
elif [ -x /data/adb/magisk/busybox ]; then
    RESETPROP="/data/adb/magisk/busybox resetprop"
fi

$RESETPROP -n ro.boot.wificountrycode AU
#resetprop -n ro.boot.hwc US
command -v iw >/dev/null 2>&1 && iw reg set AU || true