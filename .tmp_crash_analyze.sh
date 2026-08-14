#!/system/bin/sh
echo "=== 1. crash buffer 全量 (init 崩详情) ==="
logcat -d -b crash -t 300 2>/dev/null | tail -40
echo "=== 2. dmesg: mount/overlay/ksu 相关 ==="
dmesg 2>/dev/null | grep -iE "overlay|ksu|hybrid|mount|bind|dm-|f2fs|emmc|boot" | grep -viE "audit|avc" | tail -40
echo "=== 3. dmesg: avc denied (SELinux) ==="
dmesg 2>/dev/null | grep -iE "avc:.*denied" | tail -30
echo "=== 4. dmesg: wifi/hostapd/cnss ==="
dmesg 2>/dev/null | grep -iE "wlan|wifi|cnss|hostap" | tail -20
echo "=== 5. events: boot 阶段 ==="
logcat -d -b events -t 5000 2>/dev/null | grep -iE "boot_progress|boot_completed|am_proc_start.*system_server|wm_boot" | tail -20
echo "=== 6. init 服务崩溃记录 ==="
logcat -d -b system -t 3000 2>/dev/null | grep -iE "init:|Service.*died|Service.*crash|restarting" | grep -viE "netd|zygote" | tail -30
echo "=== DONE ==="
