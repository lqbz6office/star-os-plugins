#!/system/bin/sh
##########################################################################
# 课程提醒 —— 别错过下一节课
#
# 自带一份课程表(安装时会复制一份到插件数据目录,方便你自己改):
#   · 每次开机检查:距离下一节课不到 15 分钟,就弹通知提醒;
#   · 手动运行可以看今天全部课程,以及下一节课还有多久。
#
# 申请权限:notify(只弹提示)
# 课程表:优先读 $SOS_DATA/plan.txt(你自己改的那份),
#         读不到就退回内置的 res/plan.txt,所以就算数据目录不可写也能用。
##########################################################################

CB_LEAD=15                                        # 提前多少分钟提醒
CB_PLAN_DATA="$SOS_DATA/plan.txt"                 # 可改的课程表
CB_PLAN_SRC="$SOS_SRC/res/plan.txt"               # 内置课程表
CB_PLAN=""

# ---------- 安装:把内置课程表复制一份出来给用户改 ----------
if [ "$SOS_HOOK" = "install" ]; then
    if [ ! -f "$CB_PLAN_DATA" ] && [ -f "$CB_PLAN_SRC" ]; then
        cp "$CB_PLAN_SRC" "$CB_PLAN_DATA" 2>/dev/null
        if [ -f "$CB_PLAN_DATA" ]; then
            echo "课程表已复制到:$CB_PLAN_DATA"
        else
            echo "数据目录写不进去,将直接使用内置课程表"
        fi
    fi
    exit 0
fi

# ---------- 挑一份能用的课程表 ----------
if [ -f "$CB_PLAN_DATA" ]; then
    CB_PLAN="$CB_PLAN_DATA"
elif [ -f "$CB_PLAN_SRC" ]; then
    CB_PLAN="$CB_PLAN_SRC"
fi

if [ -z "$CB_PLAN" ]; then
    echo "找不到课程表(plan.txt)"
    exit 5
fi

# ---------- 今天是星期几 ----------
# %u 是 1(周一)~7(周日);个别实现没有 %u,退回 %w(0=周日)
cb_dow=""
cb_u=$(date '+%u' 2>/dev/null | tr -d ' \r\n')
case "$cb_u" in
    1) cb_dow="周一" ;;
    2) cb_dow="周二" ;;
    3) cb_dow="周三" ;;
    4) cb_dow="周四" ;;
    5) cb_dow="周五" ;;
    6) cb_dow="周六" ;;
    7) cb_dow="周日" ;;
esac

if [ -z "$cb_dow" ]; then
    cb_w=$(date '+%w' 2>/dev/null | tr -d ' \r\n')
    case "$cb_w" in
        1) cb_dow="周一" ;;
        2) cb_dow="周二" ;;
        3) cb_dow="周三" ;;
        4) cb_dow="周四" ;;
        5) cb_dow="周五" ;;
        6) cb_dow="周六" ;;
        0) cb_dow="周日" ;;
    esac
fi

if [ -z "$cb_dow" ]; then
    echo "读不到当前是星期几"
    exit 5
fi

# ---------- 现在几点(换算成当天的第几分钟) ----------
# 注意:date 给的时/分是 "08" 这种带前导零的,直接进算术会被当成八进制报错,
# 所以先用 sed 把前导零去掉,空了就当 0。
cb_h=$(date '+%H' 2>/dev/null | tr -d ' \r\n' | sed 's/^0*//')
[ -n "$cb_h" ] || cb_h=0
cb_m=$(date '+%M' 2>/dev/null | tr -d ' \r\n' | sed 's/^0*//')
[ -n "$cb_m" ] || cb_m=0
CB_NOW=$((cb_h * 60 + cb_m))

# ---------- 过一遍今天的课 ----------
CB_TOTAL=0
CB_LIST=""
CB_NEXT_NAME=""
CB_NEXT_MIN=""
CB_GAP=""

while IFS= read -r cb_line; do
    cb_line=$(printf '%s' "$cb_line" | tr -d '\r')

    # 空行和 # 开头的注释行跳过
    case "$cb_line" in
        ''|'#'*) continue ;;
    esac

    # 至少要「星期 时间」两段
    case "$cb_line" in
        *' '*) ;;
        *) continue ;;
    esac

    cb_day=${cb_line%% *}
    [ "$cb_day" = "$cb_dow" ] || continue

    cb_rest=${cb_line#* }
    cb_time=${cb_rest%% *}
    cb_name=${cb_rest#* }
    [ -n "$cb_name" ] || continue

    # 把 HH:MM 拆开、去前导零、换算成分钟
    cb_th=${cb_time%%:*}
    cb_tm=${cb_time#*:}
    cb_th=$(printf '%s' "$cb_th" | sed 's/^0*//')
    cb_tm=$(printf '%s' "$cb_tm" | sed 's/^0*//')
    [ -n "$cb_th" ] || cb_th=0
    [ -n "$cb_tm" ] || cb_tm=0
    case "$cb_th$cb_tm" in
        *[!0-9]*) continue ;;
    esac

    cb_min=$((cb_th * 60 + cb_tm))
    CB_TOTAL=$((CB_TOTAL + 1))
    CB_LIST="$CB_LIST  $cb_time  $cb_name\n"

    # 记录「离现在最近的那节还没开始的课」
    cb_gap=$((cb_min - CB_NOW))
    if [ "$cb_gap" -ge 0 ]; then
        if [ -z "$CB_GAP" ] || [ "$cb_gap" -lt "$CB_GAP" ]; then
            CB_GAP=$cb_gap
            CB_NEXT_NAME=$cb_name
            CB_NEXT_MIN=$cb_time
        fi
    fi
done < "$CB_PLAN"

# ---------- 手动运行:出一份今天的课程表 ----------
if [ "$SOS_HOOK" = "manual" ]; then
    echo "===== 课程提醒 ====="
    echo "今天 : $cb_dow  $(date '+%H:%M')"
    echo ""
    if [ "$CB_TOTAL" -eq 0 ]; then
        echo "今天没有安排课程。"
    else
        echo "今天的课($CB_TOTAL 节):"
        printf '%b' "$CB_LIST"
    fi
    echo ""
    if [ -n "$CB_NEXT_NAME" ]; then
        echo "下一节 : $CB_NEXT_MIN $CB_NEXT_NAME(还有 $CB_GAP 分钟)"
    else
        echo "下一节 : 今天的课都上完了"
    fi
    echo "课程表 : $CB_PLAN"
fi

# ---------- 开机:快到点了就提醒 ----------
if [ "$SOS_HOOK" = "boot" ]; then
    if [ -n "$CB_NEXT_NAME" ] && [ "$CB_GAP" -le "$CB_LEAD" ]; then
        echo "马上上课:$CB_NEXT_NAME(还有 $CB_GAP 分钟)"
        sos-notify "Star OS 上课提醒" "$CB_GAP 分钟后是 $CB_NEXT_NAME"
    else
        echo "开机检查完毕。今天下一节:${CB_NEXT_NAME:-没有}"
    fi
fi

exit 0
