#!/system/bin/sh
##########################################################################
# 你好插件 —— Star OS 插件的最小可用示例
#
# 它什么都不改,只是把执行器给自己的运行环境打印出来,
# 再往自己的数据目录里写一行日志。适合拿它来确认
# 「插件系统到底通不通」以及学习插件脚本怎么写。
#
# 申请权限:无 —— 所以装的时候不用授权任何东西,也不需要 root。
#           (一旦用了任何 sos-* 系统能力,就得先声明对应权限。)
# 数据位置:/data/adb/star_os/plugins/com.staros.hello/data/
##########################################################################

echo "你好,这里是 $(sos-id)"
echo "执行时间 : $(date '+%Y-%m-%d %H:%M:%S')"
echo "触发钩子 : $SOS_HOOK"
echo "插件 API : v$(sos-api)"
echo "我拿到的权限:[$(sos-perms)]"
echo "数据目录 : $SOS_DATA"
echo "工作目录 : $(pwd)"

# 往自己的数据目录写点东西(这里是插件唯一被保证可写的地方)
echo "ran at $(date '+%s') hook=$SOS_HOOK" >> "$SOS_DATA/hello.log"
echo "累计运行 : $(wc -l < "$SOS_DATA/hello.log" 2>/dev/null) 次"

exit 0
