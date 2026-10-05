#!/system/bin/sh
##########################################################################
# 亮度助手 —— 三档亮度一键切换,并且记住你选的那一档
#
# 手动运行:在「暗 / 中 / 亮」之间轮换,选中的档位记在插件数据目录里。
# 每次开机:自动恢复你上次选的档位(从没选过就完全不碰亮度,不打扰)。
#
# 申请权限:
#   settings.read  —— 读当前亮度值(读回来给你看,也用来确认改成功没有)
#   settings.write —— 真正写入亮度值
#
# 三个档位对应的亮度值(Android 亮度范围是 0-255):
#   暗 30 / 中 110 / 亮 200
# 觉得哪个档不合适,直接改下面三行里的数字。
##########################################################################

BR_STATE="$SOS_DATA/mode"
BR_DARK=30
BR_MID=110
BR_BRIGHT=200

# 当前亮度值,读不到就输出空
br_now() {
    br_v=$(sos-settings-get system screen_brightness 2>/dev/null)
    case "$br_v" in
        ''|*[!0-9]*)
            printf ''
            ;;
        *)
            printf '%s' "$br_v"
            ;;
    esac
}

# 档位名 -> 中文显示名
br_label() {
    case "$1" in
        dark)   printf '暗' ;;
        mid)    printf '中' ;;
        bright) printf '亮' ;;
        *)      printf '%s' "$1" ;;
    esac
}

# 应用一个档位:$1 = dark / mid / bright
br_apply() {
    case "$1" in
        dark)   br_val=$BR_DARK ;;
        mid)    br_val=$BR_MID ;;
        bright) br_val=$BR_BRIGHT ;;
        *)
            echo "未知档位:$1"
            return 1
            ;;
    esac

    # 系统的「自动亮度」开着的话,手写的值很快会被改回去 —— 先关掉它
    sos-settings-put system screen_brightness_mode 0 >/dev/null 2>&1
    sos-settings-put system screen_brightness "$br_val" >/dev/null 2>&1

    # 写没写进去不靠猜:读回来对一下
    br_got=$(br_now)
    if [ "$br_got" = "$br_val" ]; then
        echo "亮度已设为 $(br_label "$1")($br_val)"
        return 0
    fi
    echo "设置亮度没生效(现在读到的还是 [${br_got:-空}])"
    return 1
}

# ---------------- 手动运行:切下一档 ----------------
if [ "$SOS_HOOK" = "manual" ]; then
    br_cur=""
    [ -f "$BR_STATE" ] && br_cur=$(cat "$BR_STATE" 2>/dev/null | tr -d ' \r\n')
    case "$br_cur" in
        dark)   br_next=mid ;;
        mid)    br_next=bright ;;
        *)      br_next=dark ;;
    esac

    echo "===== 亮度助手 ====="
    echo "当前亮度 : $(br_now)"
    echo "上次档位 : $(br_label "${br_cur:-dark}")"
    echo "切换到   : $(br_label "$br_next")"
    echo ""

    if br_apply "$br_next"; then
        printf '%s\n' "$br_next" > "$BR_STATE" 2>/dev/null
        sos-notify "Star OS 亮度" "已切到「$(br_label "$br_next")」档"
    else
        sos-notify "Star OS 亮度" "改亮度没成功,看看 settings.write 权限勾了没"
    fi

    echo "现在亮度 : $(br_now)"
    exit 0
fi

# ---------------- 开机:恢复上次选的档位 ----------------
if [ "$SOS_HOOK" = "boot" ]; then
    if [ ! -f "$BR_STATE" ]; then
        echo "还没选过档位,开机不动亮度"
        exit 0
    fi
    br_last=$(cat "$BR_STATE" 2>/dev/null | tr -d ' \r\n')
    echo "开机恢复亮度档位:$(br_label "${br_last:-dark}")"
    br_apply "$br_last"
    exit 0
fi

echo "亮度助手:未处理的钩子 $SOS_HOOK"
exit 0
