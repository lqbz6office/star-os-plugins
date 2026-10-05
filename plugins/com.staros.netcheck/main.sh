#!/system/bin/sh
##########################################################################
# 网络体检 —— 看看手表到底连没连上网
#
# 手动运行:依次访问几个测试地址,报告每个地址通不通、花了多久、拿到多少字节。
# 手表上遇到「检测更新失败 / 下载失败」时,先跑这个,能看出是哪一段的问题。
#
# 申请权限:network(联网)
# 数据:探针文件写在 $SOS_DATA/ 下,每次覆盖,跑完删掉
##########################################################################

NET_TMP="$SOS_DATA/probe.bin"

# 没勾「联网」权限就直接说清楚,别让人干等
case ",$SOS_PERMS," in
    *",network,"*) ;;
    *)
        echo "没有 network 权限:去 插件中心 → 已安装 → 权限,把「联网」勾上再运行"
        exit 3
        ;;
esac

# 测一个地址:$1 = 说明,$2 = 网址
net_probe() {
    net_name="$1"
    net_url="$2"

    net_t0=$(date '+%s' 2>/dev/null)
    if sos-http "$net_url" "$NET_TMP" >/dev/null 2>&1; then
        net_t1=$(date '+%s' 2>/dev/null)
        net_sz=$(wc -c < "$NET_TMP" 2>/dev/null | tr -d ' \r\n')
        case "$net_sz" in
            ''|*[!0-9]*) net_sz=0 ;;
        esac
        net_dt=$((net_t1 - net_t0))
        echo "  [通]   $net_name  ${net_dt}s  ${net_sz} 字节"
        return 0
    fi

    echo "  [不通] $net_name"
    return 1
}

echo "===== 网络体检 ====="
echo "时间 : $(date '+%Y-%m-%d %H:%M')"
echo ""

NET_OK=0
NET_BAD=0

if net_probe "GitHub 加速通道" "https://gh-proxy.com/https://raw.githubusercontent.com/lqbz6office/star-os-plugins/main/index.json"; then
    NET_OK=$((NET_OK + 1))
else
    NET_BAD=$((NET_BAD + 1))
fi

if net_probe "jsDelivr CDN" "https://cdn.jsdelivr.net/gh/lqbz6office/star-os-plugins@main/index.json"; then
    NET_OK=$((NET_OK + 1))
else
    NET_BAD=$((NET_BAD + 1))
fi

if net_probe "普通网页(百度)" "https://www.baidu.com/"; then
    NET_OK=$((NET_OK + 1))
else
    NET_BAD=$((NET_BAD + 1))
fi

echo ""
echo "结果 : 通 $NET_OK 个 / 不通 $NET_BAD 个"
echo ""

if [ "$NET_BAD" -eq 0 ]; then
    echo "结论 : 网络一切正常。之前的下载失败多半是服务器临时抽风,过会儿再试。"
    sos-notify "Star OS 网络体检" "网络正常,$NET_OK 个测试地址全部可达"
elif [ "$NET_OK" -eq 0 ]; then
    echo "结论 : 一个地址都连不上 —— 先确认 WiFi 或流量是不是真的连上了。"
    sos-notify "Star OS 网络体检" "全部地址不通,请检查网络连接"
else
    echo "结论 : 部分地址不通,通常是加速通道的问题,换个时间再试。"
    sos-notify "Star OS 网络体检" "部分不通($NET_OK 通 / $NET_BAD 不通)"
fi

rm -f "$NET_TMP" 2>/dev/null

exit 0
