#!/system/bin/sh
##########################################################################
# 旋转锁定 —— 在「自动旋转 / 锁定方向」之间切换屏幕旋转策略
#
# 手动运行:在下面几档之间轮换,选中的档位记在插件数据目录里。
# 每次开机:自动恢复你上次选的档位(从没选过就完全不碰,不打扰)。

# 申请权限:
#   settings.read  —— 读当前设置值(读回来确认改成功没有)
#   settings.write —— 真正写入设置
#   notify         —— 弹一条提示告诉你切到哪一档
##########################################################################

ST="$SOS_DATA/state"

# 读当前值(去掉空白,读不到就给空)
pd_get() {
    sos-settings-get system accelerometer_rotation 2>/dev/null | tr -d ' \r\n'
}

# 值 -> 显示名
pd_label() {
    case "$1" in
        1)	printf '%s' '自动旋转' ;;
        0)	printf '%s' '锁定方向' ;;
        *)  printf '%s' "$1" ;;
    esac
}

# 当前值 -> 下一档
pd_next() {
    case "$1" in
        1)	printf '%s' '0' ;;
        0)	printf '%s' '1' ;;
        *)  printf '%s' '1' ;;
    esac
}

pd_apply() {
    pdv="$1"
    sos-settings-put system accelerometer_rotation "$pdv" >/dev/null 2>&1
    pdg=$(pd_get)
    if [ "$pdg" = "$pdv" ]; then
        echo "已设为「$(pd_label "$pdv")」"
        return 0
    fi
    echo "写入没生效(现在读到的还是「$(pd_label "${pdg:-空}")」)"
    return 1
}

# ---------------- 手动运行:切下一档 ----------------
if [ "$SOS_HOOK" = "manual" ]; then
    cur=$(pd_get)
    nxt=$(pd_next "$cur")
    echo "===== 旋转锁定 ====="
    echo "当前档位:「$(pd_label "${cur:-未知}")」"
    echo "切换到  :「$(pd_label "$nxt")」"
    echo ""
    if pd_apply "$nxt"; then
        printf '%s\n' "$nxt" > "$ST" 2>/dev/null
        sos-notify "Star OS 旋转锁定" "已切到「$(pd_label "$nxt")」"
    fi
    echo "现在档位:「$(pd_label "$(pd_get)")」"
    exit 0
fi

# ---------------- 开机:恢复上次档位 ----------------
if [ "$SOS_HOOK" = "boot" ]; then
    if [ ! -f "$ST" ]; then
        echo "还没选过档位,开机不动"
        exit 0
    fi
    last=$(cat "$ST" 2>/dev/null | tr -d ' \r\n')
    [ -n "$last" ] || { echo "记录是空的,开机不动"; exit 0; }
    echo "开机恢复档位:「$(pd_label "$last")」"
    pd_apply "$last"
    exit 0
fi

echo "旋转锁定:未处理的钩子 $SOS_HOOK"
exit 0
