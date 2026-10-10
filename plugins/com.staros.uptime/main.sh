#!/system/bin/sh
##########################################################################
# 运行时长 —— 手表这次开机跑了多久了 / 现在几点
#
# 手动运行:读系统运行时长,换算成 天/小时/分钟;顺便报当前时间。
# 无需任何权限(只读公开的系统计时,不碰你的数据)。
##########################################################################

up_hms() {
    # $1 = 秒
    ups=$1
    upd=$((ups / 86400))
    uph=$(( ups % 86400 / 3600 ))
    upm=$(( ups % 3600 / 60 ))
    if [ "$upd" -gt 0 ]; then
        printf '%s 天 %s 小时 %s 分' "$upd" "$uph" "$upm"
    elif [ "$uph" -gt 0 ]; then
        printf '%s 小时 %s 分' "$uph" "$upm"
    else
        printf '%s 分' "$upm"
    fi
}

if [ "$SOS_HOOK" = "manual" ]; then
    echo "===== 运行时长 ====="
    up_raw=$(cut -d' ' -f1 /proc/uptime 2>/dev/null | cut -d. -f1)
    case "$up_raw" in
        ''|*[!0-9]*) up_raw=0 ;;
    esac
    echo "本次开机已运行 : $(up_hms "$up_raw")"
    echo "当前时间       : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "当前时区       : $(date '+%Z %z')"
    echo ""
    if [ "$up_raw" -ge 259200 ]; then
        echo "提示 : 已经连续跑了 3 天以上,有空重启一下会更流畅。"
    else
        echo "提示 : 运行正常。"
    fi
fi
exit 0
