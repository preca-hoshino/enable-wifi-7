#!/system/bin/sh
# Enable Wi-Fi 6GHz & Wi-Fi 7 - 多厂商设备判断版 (v06)
# 支持: 高通(小米/OPPO/OnePlus/三星/联想/通用) / 三星 persist / 联发科(仅国家码)
# Fork of https://github.com/AndroPlus-org/magisk-module-wifi7 (© AndroPlus)
# SPDX-License-Identifier: AGPL-3.0-or-later

# ui_print 兼容（KSU/Magisk 安装器提供；直接执行时降级 echo）
info() {
    if command -v ui_print >/dev/null 2>&1; then
        ui_print "  [wifi7] $1"
    else
        echo "[wifi7] $1"
    fi
}

REPLACE="
"

WIFICFG="WCNSS_qcom_cfg.ini"

# ---------- 厂商 / SoC 检测 ----------
VENDOR=$(getprop ro.product.vendor.manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]')
[ -z "$VENDOR" ] && VENDOR=$(getprop ro.product.manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]')
SOC_MFG=$(getprop ro.soc.manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]')
BOARD=$(getprop ro.board.platform 2>/dev/null | tr '[:upper:]' '[:lower:]')

is_qcom_soc() {
    case "$SOC_MFG" in
        qcom|qualcomm) return 0 ;;
    esac
    case "$BOARD" in
        msm*|sm*|qcom*|qcm*|qcs*|kona|lahaina|taro|kalama|pineapple|sun|kiwi*|parrot|pitti|diwali|monaco|cape) return 0 ;;
    esac
    case "$(getprop ro.hardware 2>/dev/null | tr '[:upper:]' '[:lower:]')" in
        qcom*|qualcomm*) return 0 ;;
    esac
    return 1
}

# ---------- ini 处理：驱动全开放 + 802.11d 扫描关闭 ----------
# $1 = ini 文件路径（模块内拷贝）
unlock_ini() {
    local f="$1"
    # 解除频段限制（旧设备 BandCapability）
    sed -i 's@BandCapability=@#BandCapabilityMOD=@g' "$f"
    # 废掉驱动 802.11d country 扫描（避免 AP 广播国家码覆盖 AU）
    sed -i 's@^g11dSupportEnabled=1@g11dSupportEnabled=0@' "$f"

    # 驱动层 6GHz 全开放参数表（存在则强制设值，缺失则 END 前追加）
    #  oem_6g_support_disable=0           6GHz 总开关
    #  注意: 不设 SAP 相关参数 (etsi13_srd_chan_in_master_mode / gindoor_channel_support)
    #        这些只影响 SAP/P2P 角色，且驱动在 SAP 下本就不开放 6GHz；
    #        移除可避免驱动尝试未预期的信道组合导致 boot 卡死 (QCOM watchdog 25s 重启)
    local force_params="oem_6g_support_disable=0"
    local p name val
    for p in $force_params; do
        name="${p%%=*}"
        val="${p#*=}"
        if grep -q "^${name}=" "$f"; then
            sed -i "s@^${name}=.*@${name}=${val}@" "$f"
        else
            sed -i "s@^END$@${name}=${val}\nEND@" "$f"
        fi
    done

    # 模块标记注释行（post-fs-data.sh 据此检测 overlay 是否生效；解析器忽略注释）
    grep -q '^# enable-wifi-7 module' "$f" || sed -i 's@^END$@# enable-wifi-7 module: unlocked\nEND@' "$f"
}

# ---------- 高通方案：定位并安装 WCNSS ini 到模块 overlay ----------
install_qcom_ini() {
    # 1. 权威芯片型号：驱动报告（dumpsys wifi 的 "HW:XXX"，如 KIWI_V2/qca6490）
    #    多 SKU 的 vendor 常预置多套 ini，字典序通配符可能选错（如 kiwi vs qca6490）
    CHIP=$(dumpsys wifi 2>/dev/null | grep -o 'HW:[A-Za-z0-9_]*' | head -1 | cut -d: -f2 | tr '[:upper:]' '[:lower:]')
    [ -z "$CHIP" ] && CHIP=$(getprop ro.wifi.chipset 2>/dev/null | tr '[:upper:]' '[:lower:]')
    [ -z "$CHIP" ] && CHIP=$(getprop ro.vendor.wifi.chipset 2>/dev/null | tr '[:upper:]' '[:lower:]')

    # 2. 候选路径按厂商偏好 + 芯片型号排序
    case "$VENDOR" in
        oppo|oneplus|realme|nothing)
            CANDIDATES="/odm/vendor/etc/wifi/${WIFICFG} /odm/vendor/etc/wifi/*/${WIFICFG}"
            FALLBACK="/vendor/etc/wifi/${WIFICFG} /vendor/etc/wifi/*/${WIFICFG}" ;;
        *)
            CANDIDATES="/vendor/etc/wifi/${WIFICFG} /vendor/etc/wifi/*/${WIFICFG}"
            FALLBACK="/odm/vendor/etc/wifi/${WIFICFG} /odm/vendor/etc/wifi/*/${WIFICFG}" ;;
    esac

    local src=""
    # 3. 芯片型号精确目录优先（避免通配符选错多 SKU 目录）
    if [ -n "$CHIP" ]; then
        for candidate in /vendor/etc/wifi/${CHIP}/${WIFICFG} /odm/vendor/etc/wifi/${CHIP}/${WIFICFG} $CANDIDATES; do
            if [ -e "$candidate" ]; then
                src="$candidate"
                break
            fi
        done
    fi
    # 4. 通配符兜底
    if [ -z "$src" ]; then
        for candidate in $CANDIDATES $FALLBACK; do
            if [ -e "$candidate" ]; then
                src="$candidate"
                break
            fi
        done
    fi

    if [ -z "$src" ]; then
        info "no WCNSS_qcom_cfg.ini found, country-code only"
        return 1
    fi

    # 目标：模块 system/ 目录（KSU/Magisk 自动 overlay 挂载到 /vendor 或 /odm）
    local rel="${src#/}"   # 去掉前导 /
    local dest="${MODPATH}/system/${rel}"
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
    unlock_ini "$dest"
    # 保留模块内副本 + 源路径记录（post-fs-data.sh bind mount fallback 用）
    mkdir -p "${MODPATH}/xml"
    cp -a "$src" "${MODPATH}/xml/${WIFICFG}"
    unlock_ini "${MODPATH}/xml/${WIFICFG}"
    echo "$src" > "${MODPATH}/xml/wificfg_source"
    info "unlocked: $src"
    return 0
}

# ---------- 三星方案：persist 分区（overlay 管不到，安装时直接改真实文件）----------
install_samsung_persist() {
    if [ -e "/mnt/vendor/persist/wlan/${WIFICFG}" ]; then
        sed -i 's@BandCapability=@#BandCapabilityMOD=@g' "/mnt/vendor/persist/wlan/${WIFICFG}"
        sed -i 's@enable_11be=0@enable_11be=1@g' "/mnt/vendor/persist/wlan/${WIFICFG}"
        sed -i 's@^g11dSupportEnabled=1@g11dSupportEnabled=0@' "/mnt/vendor/persist/wlan/${WIFICFG}"
        info "samsung persist patched"
    fi
}

# ---------- 主流程 ----------
if is_qcom_soc || [ -n "$(ls /vendor/etc/wifi/*/${WIFICFG} /odm/vendor/etc/wifi/*/${WIFICFG} 2>/dev/null | head -1)" ]; then
    install_qcom_ini
else
    info "non-Qualcomm SoC, country-code only"
fi

# 三星 persist（与 SoC 无关，独立检测）
case "$VENDOR" in
    samsung) install_samsung_persist ;;
esac

info "vendor=${VENDOR:-unknown} soc=${SOC_MFG:-unknown}"
