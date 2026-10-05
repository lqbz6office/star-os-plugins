#!/system/bin/sh
##########################################################################
# 空间哨兵 —— 存储空间告警
#
# 检查 /data 分区剩余空间:低于 1GB 提醒,低于 300MB 严重告警。
# 手动运行则打印一份完整的存储报告。
#
# 申请权限:notify(只弹提示)
# 数据:不存数据,纯检查
#
# 说明:df 是纯查看命令,不需要任何权限。
##########################################################################

SP_WARN_MB=1024    # 剩余低于这个数(MB)就提醒
SP_CRIT_MB=300     # 剩余低于这个数(MB)就严重告警

# 解析 df -k /data 的那一行。
# df 的标准列序是:文件系统 总容量 已用 可用 使用率 挂载点,
# 所以取第 2/3/4/5 列。用 for 分词而不是 awk —— 别指望设备上一定有 awk。
sp_parse() {
    sp_line=$(df -k /data 2>/dev/null | tail -n 1)
    [ -n "$sp_line" ] || return 1

    sp_i=0
    sp_total=""
    sp_used=""
    sp_avail=""
    sp_pct=""

    for sp_f in $sp_line; do
        sp_i=$((sp_i + 1))
        case "$sp_i" in
            2) sp_total=$sp_f ;;
            3) sp_used=$sp_f ;;
            4) sp_avail=$sp_f ;;
            5) sp_pct=$sp_f ;;
        esac
    done

    case "$sp_avail" in
        ''|*[!0-9]*) return 1 ;;
    esac
    return 0
}

if ! sp_parse; then
    echo "读不到 /data 的空间信息(df 输出和预期不一样)"
    sos-log "解析 df 输出失败"
    if [ "$SOS_HOOK" = "manual" ]; then
        sos-notify "空间哨兵" "这台设备读不到存储信息"
    fi
    exit 0
fi

SP_TOTAL_MB=$((sp_total / 1024))
SP_USED_MB=$((sp_used / 1024))
SP_AVAIL_MB=$((sp_avail / 1024))

if [ "$SOS_HOOK" = "manual" ]; then
    echo "===== 存储报告 ====="
    echo "分区 : /data"
    echo "总量 : $SP_TOTAL_MB MB"
    echo "已用 : $SP_USED_MB MB"
    echo "剩余 : $SP_AVAIL_MB MB(使用率 ${sp_pct:-未知})"
    echo ""
    if [ "$SP_AVAIL_MB" -le "$SP_CRIT_MB" ]; then
        echo "结论 : 空间非常紧张,建议尽快清理"
    elif [ "$SP_AVAIL_MB" -le "$SP_WARN_MB" ]; then
        echo "结论 : 空间偏少,有空清一清"
    else
        echo "结论 : 空间充足"
    fi
    echo ""
    echo "手表上占地方的通常是这几样:"
    echo "  · 相册里的照片和视频"
    echo "  · 录音、下载的歌曲"
    echo "  · 内部存储里遗留的安装包和压缩包"
fi

# ---- 告警 ----
if [ "$SP_AVAIL_MB" -le "$SP_CRIT_MB" ]; then
    echo "严重告警:剩余 $SP_AVAIL_MB MB"
    sos-notify "Star OS 空间告警" "剩余空间只剩 $SP_AVAIL_MB MB,请尽快清理"
elif [ "$SP_AVAIL_MB" -le "$SP_WARN_MB" ]; then
    echo "空间提醒:剩余 $SP_AVAIL_MB MB"
    sos-notify "Star OS 空间提醒" "剩余空间 $SP_AVAIL_MB MB,建议清理一下"
fi

exit 0
