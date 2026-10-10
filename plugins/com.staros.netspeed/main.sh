#!/system/bin/sh
##########################################################################
# 网速测速 —— 从一个固定文件测下载速度,看手表网络快不快
#
# 手动运行:下载一个测试文件,按用时和大小估算下载速度(KB/s)。
# 申请权限:network(联网)
# 数据:测试文件写在 $SOS_DATA/ 下,下次运行覆盖
##########################################################################

SP_TMP="$SOS_DATA/speed.bin"

case ",$SOS_PERMS," in
    *",network,"*) ;;
    *) echo "没有 network 权限:去 已安装 → 权限,把「联网」勾上再运行"; exit 3 ;;
esac

if [ "$SOS_HOOK" = "manual" ]; then
    echo "===== 网速测速 ====="
    echo "下载测试文件(约 1 MB,请稍等)…"
    sp_url="https://speed.cloudflare.com/__down?bytes=1000000"
    sp_t0=$(date '+%s' 2>/dev/null)
    if sos-http "$sp_url" "$SP_TMP" >/dev/null 2>&1; then
        sp_t1=$(date '+%s' 2>/dev/null)
        sp_sz=$(wc -c < "$SP_TMP" 2>/dev/null | tr -d ' \r\n')
        case "$sp_sz" in ''|*[!0-9]*) sp_sz=0 ;; esac
        sp_dt=$((sp_t1 - sp_t0))
        [ "$sp_dt" -lt 1 ] && sp_dt=1
        case "$sp_sz" in
            ''|*[!0-9]*) sp_sz=0 ;;
        esac
        sp_kb=$((sp_sz / 1024))
        sp_rate=$((sp_kb / sp_dt))
        echo "下载大小 : ${sp_kb} KB"
        echo "用时     : ${sp_dt} 秒"
        echo "约合速度 : ${sp_rate} KB/s"
        if [ "$sp_rate" -ge 500 ]; then
            echo "结论     : 网速很好。"
        elif [ "$sp_rate" -ge 100 ]; then
            echo "结论     : 网速够用。"
        else
            echo "结论     : 偏慢,下载大文件会比较久。"
        fi
        sos-notify "Star OS 网速" "约 ${sp_rate} KB/s"
    else
        echo "测试文件下载失败 —— 先确认网络连上了。"
        sos-notify "Star OS 网速" "测速失败,请检查网络"
    fi
fi

# 测试文件不删:下次运行会被覆盖
true > "$SP_TMP" 2>/dev/null
exit 0
