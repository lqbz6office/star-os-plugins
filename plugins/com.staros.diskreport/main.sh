#!/system/bin/sh
##########################################################################
# 存储体检 —— 看看内部存储里哪个目录文件最多,帮你找出该清理的地方
#
# 手动运行:列出 /sdcard 下各个常用目录的文件条数,按多少排序。
# 申请权限:storage.read(读取内部存储目录列表)
##########################################################################

case ",$SOS_PERMS," in
    *",storage.read,"*) ;;
    *) echo "没有 storage.read 权限:去 已安装 → 权限,把「读取存储」勾上再运行"; exit 3 ;;
esac

dk_dir() {
    # 数一个目录下的条目数(含隐藏)。ls -la 前 3 行是 total / .  / ..,减掉。
    dk_n=$(sos-fs-list "$1" 2>/dev/null | grep -c . )
    case "$dk_n" in ''|*[!0-9]*) dk_n=0 ;; esac
    dk_n=$((dk_n - 3))
    [ "$dk_n" -lt 0 ] && dk_n=0
    printf '%s' "$dk_n"
}

if [ "$SOS_HOOK" = "manual" ]; then
    echo "===== 存储体检 ====="
    echo "时间 : $(date '+%Y-%m-%d %H:%M')"
    echo ""
    echo "内部存储各目录条目数:"
    dk_big=""
    dk_big_n=0
    for dk_d in /sdcard/Download /sdcard/DCIM /sdcard/Pictures /sdcard/Android /sdcard/StarOS /sdcard/Music /sdcard/Movies; do
        dk_c=$(dk_dir "$dk_d")
        printf '  %-24s %s 项\n' "$dk_d" "$dk_c"
        if [ "$dk_c" -gt "$dk_big_n" ]; then dk_big_n="$dk_c"; dk_big="$dk_d"; fi
    done
    echo ""
    if [ "$dk_big_n" -gt 30 ]; then
        echo "结论 : 「$dk_big」条目最多($dk_big_n 项),可以去看看有没有能删的。"
        sos-notify "Star OS 存储体检" "$dk_big 有 $dk_big_n 项,最多"
    else
        echo "结论 : 各目录都不算多,内部存储很清爽。"
        sos-notify "Star OS 存储体检" "存储清爽,无需清理"
    fi
fi
exit 0
