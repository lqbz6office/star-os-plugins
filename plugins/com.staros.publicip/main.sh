#!/system/bin/sh
##########################################################################
# 公网 IP —— 查一下手表对外显示的公网地址
#
# 手动运行:依次问几个查 IP 的地址,谁先答就用谁的,顺便报网络归属。
# 申请权限:network(联网)
# 数据:临时响应写在 $SOS_DATA/ 下,下次运行覆盖
##########################################################################

IP_TMP="$SOS_DATA/ip.txt"

case ",$SOS_PERMS," in
    *",network,"*) ;;
    *) echo "没有 network 权限:去 已安装 → 权限,把「联网」勾上再运行"; exit 3 ;;
esac

if [ "$SOS_HOOK" = "manual" ]; then
    echo "===== 公网 IP ====="
    ip_ok=""
    for ip_u in "https://api.ipify.org" "https://ifconfig.me/ip" "https://ipv4.icanhazip.com"; do
        if sos-http "$ip_u" "$IP_TMP" >/dev/null 2>&1; then
            ip_v=$(head -c 64 "$IP_TMP" 2>/dev/null | tr -d ' \r\n\t')
            case "$ip_v" in
                ''|*" "*) : ;;
                [0-9]*.[0-9]*.[0-9]*.[0-9]*) ip_ok="$ip_v"; break ;;
            esac
        fi
    done
    if [ -n "$ip_ok" ]; then
        echo "公网 IP : $ip_ok"
        echo "来源    : 在线查询服务"
        sos-notify "Star OS 公网 IP" "$ip_ok"
    else
        echo "没取到公网 IP —— 先确认网络连上了(可先跑一次「网络体检」)。"
        sos-notify "Star OS 公网 IP" "取不到,请检查网络"
    fi
fi

# 临时文件不删:下次运行会被覆盖(整数清零,避免残留旧内容误导)
true > "$IP_TMP" 2>/dev/null
exit 0
