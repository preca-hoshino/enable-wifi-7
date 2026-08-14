#!/system/bin/sh
echo "=== boot 状态 ==="
echo "sys.boot_completed=$(getprop sys.boot_completed)"
echo "sys.boot.reason=$(getprop sys.boot.reason 2>/dev/null)"
echo "init.svc.bootanim=$(getprop init.svc.bootanim 2>/dev/null)"
echo "service.bootanim.exit=$(getprop service.bootanim.exit 2>/dev/null)"
echo "uptime=$(awk '{print $1}' /proc/uptime)"
echo "=== boot 阶段 ==="
getprop | grep -iE "boot.*(complete|anim|progress)|sys.boot" | head -10
echo "=== 模块状态 ==="
if [ -d /data/adb/modules/enable-wifi-7 ]; then
  echo "模块存在: version=$(grep '^version=' /data/adb/modules/enable-wifi-7/module.prop 2>/dev/null)"
  ls /data/adb/modules/enable-wifi-7/
else
  echo "模块不存在"
fi
echo "=== disable/remove 标记 ==="
ls /data/adb/modules/enable-wifi-7/disable /data/adb/modules/enable-wifi-7/remove 2>/dev/null || echo "无标记"
echo "=== system_server / zygote ==="
ps -A 2>/dev/null | grep -E "system_server|zygote" | head -5
echo "=== wifi 服务 ==="
ps -A 2>/dev/null | grep -iE "wifi" | head -5
echo "=== 最近 crash ==="
logcat -d -b crash -t 200 2>/dev/null | tail -20
echo "=== DONE ==="
