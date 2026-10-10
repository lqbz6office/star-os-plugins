#!/system/bin/sh
##########################################################################
# 时间体检 —— 看看手表时间是不是自动校准的,时间不准一键开自动校时
#
# 手动运行:报告「自动确定时间 / 自动确定时区」开没开、当前时区;
#           两个只要有一个没开,就提示可以一键打开。
# 申请权限:
#   settings.read  —— 读自动校时开关与时区
#   settings.write —— 打开自动校时
#   notify         —— 结果弹一条提示
##########################################################################

at_get() {
    sos-settings-get global "$1" 2>/dev/null | tr -d ' \r\n'
}

at_state() {
    case "$1" in
        1) printf '已开启' ;;
        0) printf '已关闭' ;;
        *) printf '未知' ;;
    esac
}

if [ "$SOS_HOOK" = "manual" ]; then
    echo "===== 时间体检 ====="
    echo "时间 : $(date '+%Y-%m-%d %H:%M:%S')"
    at_t=$(at_get auto_time)
    at_z=$(at_get auto_time_zone)
    echo "自动确定时间 : $(at_state "$at_t")"
    echo "自动确定时区 : $(at_state "$at_z")"
    echo ""
    if [ "$at_t" = "1" ] && [ "$at_z" = "1" ]; then
        echo "结论 : 时间由网络自动校准,不用管。"
        sos-notify "Star OS 时间体检" "自动校时已开启,时间准确"
        exit 0
    fi
    echo "结论 : 有开关没打开,时间可能不准 —— 正在尝试打开。"
    sos-settings-put global auto_time 1 >/dev/null 2>&1
    sos-settings-put global auto_time_zone 1 >/dev/null 2>&1
    if [ "$(at_get auto_time)" = "1" ] && [ "$(at_get auto_time_zone)" = "1" ]; then
        echo "已开启自动确定时间与时区。"
        sos-notify "Star OS 时间体检" "已开启自动校时"
    else
        echo "打开失败,可能这台机器限制了写安全设置(settings.write)。"
        sos-notify "Star OS 时间体检" "自动校时没打开,请检查权限"
    fi
    exit 0
fi

echo "时间体检:未处理的钩子 $SOS_HOOK"
exit 0
