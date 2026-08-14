#!/system/bin/sh
LOG=/data/adb/ksu/log/logcat.old.log
echo "=== 1. boot_progress 时间线 ==="
grep -aE "boot_progress" "$LOG" 2>/dev/null | head -20
echo "=== 2. Watchdog / hang ==="
grep -aE "Watchdog|watchdog|Killing system|hung|HUNG|not responding" "$LOG" 2>/dev/null | head -20
echo "=== 3. system_server FATAL / crash ==="
grep -aE "FATAL|Fatal|SystemServer.*crash|system_server.*died|RuntimeInit" "$LOG" 2>/dev/null | head -20
echo "=== 4. wifi / hostapd / wificond 崩溃循环 ==="
grep -aE "wificond|hostapd|WifiService|WifiHAL" "$LOG" 2>/dev/null | grep -iE "died|crash|fatal|error|failed|restart" | head -20
echo "=== 5. enable-wifi-7 / status.sh / ksu 模块 ==="
grep -aE "enable-wifi-7|status.sh|wifi7" "$LOG" 2>/dev/null | head -20
echo "=== 6. init: 服务重启循环 ==="
grep -aE "init: Service.*(died|restarting|crash)" "$LOG" 2>/dev/null | head -20
echo "=== 7. overlay / PMS ==="
grep -aE "OverlayManager|overlay.*wifi7|PackageManager.*crash|PMS.*fatal" "$LOG" 2>/dev/null | head -10
echo "=== 8. 日志最后 50 行 (boot 卡住时的现场) ==="
tail -50 "$LOG" 2>/dev/null
echo "=== DONE ==="
