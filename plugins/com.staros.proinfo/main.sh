#!/system/bin/sh
##########################################################################
# 授权信息 —— 看看本机当前是免费版还是 Pro/Pro+,什么时候到期
#
# 手动运行:打印授权等级、设备码、到期日。遇到「功能用不了」先跑这个。
# 无需任何权限(只读本机授权状态)。
##########################################################################

if [ "$SOS_HOOK" = "manual" ]; then
    echo "===== 授权信息 ====="
    pi_line=$(sos-pro 2>/dev/null)
    echo "原始状态 : ${pi_line:-读不到}"
    pi_tier=$(printf '%s' "$pi_line" | sed -n 's/.*tier=\([0-9]*\).*/\1/p')
    case "$pi_tier" in ''|*[!0-9]*) pi_tier=0 ;; esac
    if [ "$pi_tier" -ge 2 ]; then
        echo "当前版本 : Pro+ / 终身版(等级 $pi_tier)"
    elif [ "$pi_tier" -ge 1 ]; then
        echo "当前版本 : Pro(等级 $pi_tier)"
    else
        echo "当前版本 : 免费版"
        echo "提示     : 实验室里的 Pro+ 功能需要激活后才能用。"
    fi
    pi_exp=$(sed -n 's/^expiry=//p' /data/adb/star_os/pro.conf 2>/dev/null | head -n 1)
    if [ -n "$pi_exp" ]; then
        echo "到期日期 : $pi_exp"
    fi
    sos-notify "Star OS 授权" "等级 $pi_tier"
fi
exit 0
