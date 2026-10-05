#!/system/bin/sh
##########################################################################
# 每日一句 —— 演示「带资源文件 + 开机钩子 + 通知」的插件
#
# 每次开机从 res/tips.txt 里随机挑一条,弹个通知。
# 也可以手动运行,效果一样。
#
# 申请权限:notify(只弹提示,碰不到系统任何东西)
# 资源文件:res/tips.txt,一行一条
##########################################################################

TIPS="$SOS_SRC/res/tips.txt"

if [ ! -f "$TIPS" ]; then
    sos-log "找不到 tips.txt"
    echo "找不到资源文件 $TIPS"
    exit 5
fi

TOTAL=$(wc -l < "$TIPS" 2>/dev/null)
case "$TOTAL" in ''|*[!0-9]*) TOTAL=0 ;; esac
if [ "$TOTAL" -lt 1 ]; then
    echo "tips.txt 是空的"
    exit 5
fi

# 用秒数取模当随机数,不依赖 $RANDOM(busybox ash 不一定有)
N=$(( $(date '+%s') % TOTAL + 1 ))
TIP=$(sed -n "${N}p" "$TIPS")

echo "本次抽到第 $N / $TOTAL 条:$TIP"
sos-notify "Star OS 小贴士" "$TIP"

exit 0
