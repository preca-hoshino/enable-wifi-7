#!/system/bin/sh
LOG=/data/adb/ksu/log/dmesg.old.log
echo "=== 1. dmesg.old 尾部 60 行 (01:01 boot 结束时的内核现场) ==="
tail -60 "$LOG" 2>/dev/null
echo "=== 2. watchdog / panic / reboot 关键字 ==="
grep -aE "watchdog|Watchdog|panic|Panic|hard lockup|soft lockup|reboot|hung task|Kernel panic|BUG:" "$LOG" 2>/dev/null | tail -20
echo "=== 3. init 相关 (SIGABRT 上下文) ==="
grep -aE "init.*(signal|abort|SIGABRT|restarting|killed)" "$LOG" 2>/dev/null | tail -20
echo "=== 4. 模块 ini / overlay 挂载痕迹 ==="
grep -aE "hm_|Ks9|overlay.*wifi|WCNSS" "$LOG" 2>/dev/null | tail -20
echo "=== 5. KernelSU hook ==="
grep -aE "KernelSU|ksu_" "$LOG" 2>/dev/null | tail -20
echo "=== DONE ==="
