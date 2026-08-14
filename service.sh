#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future

{
    # Wait for boot completed
    until [ "$(getprop sys.boot_completed)" = "1" ]; do
        sleep 10
    done

    # Wait for wifi service ready
    i=0
    while [ $i -lt 60 ]; do
        cmd wifi get-country-code >/dev/null 2>&1 && break
        sleep 2
        i=$((i + 1))
    done

    # 1. 持久化国家码兜底：改写 WifiConfigStore.xml（wifi 服务重启后不会回 CN）
    WIFI_STORE=/data/misc/apexdata/com.android.wifi/WifiConfigStore.xml
    if [ -f "$WIFI_STORE" ]; then
        cp "$WIFI_STORE" "${WIFI_STORE}.bak_wifi7" 2>/dev/null
        sed -i 's@<string name="wifi_last_country_code">CN</string>@<string name="wifi_last_country_code">AU</string>@g' "$WIFI_STORE"
        sed -i 's@<string name="wifi_default_country_code">CN</string>@<string name="wifi_default_country_code">AU</string>@g' "$WIFI_STORE"
        chown wifi:wifi "$WIFI_STORE" 2>/dev/null
        chmod 660 "$WIFI_STORE" 2>/dev/null
        restorecon "$WIFI_STORE" 2>/dev/null
    fi

    # 2. 废掉框架国家码扫描/回退（Android 14+ 资源强制覆盖，失败无碍）
    cmd wifi force-overlay-config-value bool config_wifiUpdateCountryCodeFromScanResultGeneric enabled false 2>/dev/null
    cmd wifi force-overlay-config-value bool config_wifi_revert_country_code_on_cellular_loss enabled false 2>/dev/null

    # 3. 强制国家码 AU（override 优先级最高，压过 telephony/扫描/driver）
    cmd wifi force-country-code enabled AU

    # 4. 动态状态描述（KSU Manager / MMRL 等显示频段解锁状态）
    #    等待 wifi 驱动就绪 + 信道表填充后刷新
    sleep 20
    sh "${MODDIR}/status.sh" >/dev/null 2>&1
}&