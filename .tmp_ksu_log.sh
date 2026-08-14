#!/system/bin/sh
echo "=== 1. KSU log 目录 ==="
ls -la /data/adb/ksu/log/ 2>/dev/null
for f in /data/adb/ksu/log/*; do
  [ -f "$f" ] && { echo "--- $f:"; tail -30 "$f" 2>/dev/null; }
done
echo "=== 2. dropbox SYSTEM_BOOT 详细 (最后 3 个) ==="
for f in $(ls -t /data/system/dropbox/SYSTEM_BOOT* 2>/dev/null | head -3); do
  echo "--- $f:"
  grep -iE "boot|reboot|reason|crash|error|wifi|overlay|ksu|mount" "$f" 2>/dev/null | head -15
done
echo "=== 3. dropbox 其他崩溃类 ==="
ls -t /data/system/dropbox/ 2>/dev/null | grep -viE "SYSTEM_BOOT|BATTERY|EVENTLOG|notification|system_app_wtf|telephony" | head -15
echo "=== 4. last reboot reason ==="
getprop sys.boot.reason
getprop persist.sys.boot.reason.history 2>/dev/null
echo "=== 5. 是否有 minidump/ramdump ==="
ls /data/vendor/ramdump /data/vendor/minidump 2>/dev/null | head -5
echo "=== DONE ==="
