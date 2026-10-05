#!/system/bin/sh
##########################################################################
# 电量守护 —— 低电提醒 / 充满提醒 / 电量速查
#
# 每次开机检查一次电量:低于 20% 提醒充电,充到 95% 以上提醒拔充电器。
# 在应用里手动运行则打印完整状态(电量 / 充电状态 / 温度)和最近几次记录。
#
# 申请权限:notify(只弹提示,碰不到系统任何东西)
# 数据:每次运行的记录追加到 $SOS_DATA/battery.log,只保留最近 100 行
#
# 说明:电量从 /sys/class/power_supply 下的节点读,这是纯查看,不需要权限。
#       不同机型节点名不一样,下面挨个试,都读不到就算本机不支持。
##########################################################################

BG_LOG="$SOS_DATA/battery.log"
BG_LOW=20        # 低电阈值(%),到这个数就提醒充电
BG_FULL=95       # 满电阈值(%),充电时到这个数就提醒拔掉
BG_KEEP=100      # 日志最多留多少行

# ---- 电量(%) ----
bg_capacity() {
    for bg_p in /sys/class/power_supply/battery/capacity /sys/class/power_supply/BATTERY/capacity /sys/class/power_supply/bms/capacity /sys/class/power_supply/battery/soc; do
        [ -r "$bg_p" ] || continue
        bg_v=$(cat "$bg_p" 2>/dev/null | tr -d ' \r\n')
        case "$bg_v" in
            ''|*[!0-9]*) continue ;;
        esac
        printf '%s' "$bg_v"
        return 0
    done
    return 0
}

# ---- 充电状态(Charging / Discharging / Full ...) ----
bg_status() {
    for bg_p in /sys/class/power_supply/battery/status /sys/class/power_supply/BATTERY/status; do
        [ -r "$bg_p" ] || continue
        bg_v=$(cat "$bg_p" 2>/dev/null | tr -d ' \r\n')
        if [ -n "$bg_v" ]; then
            printf '%s' "$bg_v"
            return 0
        fi
    done
    return 0
}

# ---- 电池温度 ----
# 多数机型给的是「0.1 摄氏度」的整数(320 表示 32.0 度),少数直接给摄氏度。
bg_temp() {
    for bg_p in /sys/class/power_supply/battery/temp /sys/class/power_supply/BATTERY/temp; do
        [ -r "$bg_p" ] || continue
        bg_v=$(cat "$bg_p" 2>/dev/null | tr -d ' \r\n')
        case "$bg_v" in
            ''|*[!0-9-]*) continue ;;
        esac
        printf '%s' "$bg_v"
        return 0
    done
    return 0
}

BG_CAP=$(bg_capacity)
BG_ST=$(bg_status)
BG_T=$(bg_temp)

# 是否在充电:先看 status,status 读不到再退一步看 ac/usb 的 online 标志
BG_CHG=0
case "$BG_ST" in
    Charging|Full|charging|full|CHARGING|FULL) BG_CHG=1 ;;
esac
if [ "$BG_CHG" = "0" ] && [ -z "$BG_ST" ]; then
    for bg_p in /sys/class/power_supply/ac/online /sys/class/power_supply/usb/online /sys/class/power_supply/AC/online; do
        [ -r "$bg_p" ] || continue
        bg_v=$(cat "$bg_p" 2>/dev/null | tr -d ' \r\n')
        [ "$bg_v" = "1" ] && BG_CHG=1
    done
fi

# 读不到电量:明确说清楚,别让人以为是插件坏了
if [ -z "$BG_CAP" ]; then
    echo "读不到电量:这台设备没有暴露 sysfs 电量节点"
    sos-log "读不到电量节点"
    if [ "$SOS_HOOK" = "manual" ]; then
        sos-notify "电量守护" "这台设备读不到电量信息"
    fi
    exit 0
fi

# 温度显示(统一成「度」)
bg_show_temp() {
    if [ -z "$BG_T" ]; then
        echo "温度 : 读不到"
    elif [ "$BG_T" -gt 200 ]; then
        echo "温度 : $((BG_T / 10)).$((BG_T % 10)) 度"
    else
        echo "温度 : $BG_T 度"
    fi
}

if [ "$SOS_HOOK" = "manual" ]; then
    echo "===== 电量速查 ====="
    echo "电量 : $BG_CAP%"
    echo "状态 : ${BG_ST:-未知}"
    if [ "$BG_CHG" = "1" ]; then
        echo "充电 : 正在充电"
    else
        echo "充电 : 未充电"
    fi
    bg_show_temp
    echo ""
    echo "阈值 : 低于 $BG_LOW% 提醒 / 充电到 $BG_FULL% 提醒"
    echo ""
    echo "最近记录:"
    tail -5 "$BG_LOG" 2>/dev/null
fi

# ---- 提醒 ----
if [ "$BG_CHG" = "1" ] && [ "$BG_CAP" -ge "$BG_FULL" ]; then
    echo "已充满:$BG_CAP%"
    sos-notify "电量守护" "电量已 $BG_CAP%,可以拔充电器了"
fi

if [ "$BG_CHG" = "0" ] && [ "$BG_CAP" -le "$BG_LOW" ]; then
    echo "电量偏低:$BG_CAP%"
    sos-notify "电量守护" "电量只剩 $BG_CAP%,记得充电"
fi

# ---- 记一笔(只留最近 BG_KEEP 行,免得日志无限长) ----
echo "$(date '+%m-%d %H:%M') 电量 $BG_CAP% 状态 ${BG_ST:-?} 充电 $BG_CHG" >> "$BG_LOG" 2>/dev/null

BG_N=$(wc -l < "$BG_LOG" 2>/dev/null)
case "$BG_N" in ''|*[!0-9]*) BG_N=0 ;; esac
if [ "$BG_N" -gt "$BG_KEEP" ]; then
    if tail -"$BG_KEEP" "$BG_LOG" > "$BG_LOG.tmp" 2>/dev/null; then
        mv -f "$BG_LOG.tmp" "$BG_LOG" 2>/dev/null
    fi
fi

exit 0
