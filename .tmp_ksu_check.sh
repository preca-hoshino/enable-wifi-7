#!/system/bin/sh
echo "=== 1. 当前时间 vs uptime (对齐崩溃时间) ==="
date '+%m-%d %H:%M:%S'
uptime
awk '{print "uptime_sec:", $1}' /proc/uptime
echo "=== 2. KSU hybrid mount 目录 ==="
ls -la /mnt/hm_* 2>/dev/null | head -20
echo "--- /mnt/Ks9wBUKmu3 (旧 overlay 缓存):"
ls /mnt/ | grep -iE "ksu|hm_" 
echo "=== 3. 当前 /vendor overlay 挂载 ==="
mount | grep -E "overlay|/vendor" | head -10
echo "=== 4. KSU 模块列表 ==="
ls /data/adb/modules/ 2>/dev/null
echo "=== 5. KSU 日志 ==="
ls -la /data/adb/ksu/ 2>/dev/null | head
logcat -d -t 3000 2>/dev/null | grep -iE "KernelSU|ksud" | tail -20
echo "=== 6. dropbox 崩溃记录 ==="
ls /data/system/dropbox/ 2>/dev/null | grep -iE "crash|system_server|reboot|boot" | tail -10
echo "=== 7. boot 相关 events ==="
logcat -d -b events -t 10000 2>/dev/null | grep -iE "boot_progress_enable_screen|sysui|launcher" | tail -10
echo "=== 8. 当前是否残留 wifi7 痕迹 ==="
grep -r "enable-wifi-7\|wifi7" /data/adb/ 2>/dev/null | grep -v Binary | head -10
echo "=== DONE ==="
