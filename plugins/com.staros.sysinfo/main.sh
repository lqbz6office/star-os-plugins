#!/system/bin/sh
##########################################################################
# 系统信息 —— 只读插件示例
#
# 手动运行,把设备的关键信息列出来。
# 用来演示「只申请一个中风险权限(settings.read)、只读不写」的插件长什么样。
#
# 申请权限:settings.read(读系统属性)
# 它不写任何东西,所以就算授权了也改不动系统。
##########################################################################

echo "===== 设备信息 ====="
echo "型号      : $(sos-getprop ro.product.model)"
echo "Android   : $(sos-getprop ro.build.version.release)"
echo "SDK       : $(sos-getprop ro.build.version.sdk)"
echo "描述(本模块): $(sos-getprop ro.product.careme.version)"

echo ""
echo "===== 运行状态 ====="
echo "开机时长  : $(cut -d. -f1 /proc/uptime 2>/dev/null) 秒"

echo ""
echo "===== 内存(MB) ====="
if [ -r /proc/meminfo ]; then
    head -3 /proc/meminfo
else
    echo "(读不到 /proc/meminfo)"
fi

echo ""
echo "===== 存储 ====="
df -h /data 2>/dev/null | head -2

exit 0
