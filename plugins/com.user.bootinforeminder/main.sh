#!/system/bin/sh
# ============================================================
# 开机信息提醒插件
# 功能：开机弹窗显示 日期/时间/电量/WiFi名称/音量
# 权限：notify, settings.read
# ============================================================

sos-log "===== 开机信息提醒开始 ====="

# ---------- 1. 日期与时间 ----------
CURRENT_DATE=$(date '+%Y年%m月%d日')
CURRENT_TIME=$(date '+%H:%M:%S')
WEEKDAY_NUM=$(date '+%u')
case "$WEEKDAY_NUM" in
    1) WEEKDAY="星期一" ;;
    2) WEEKDAY="星期二" ;;
    3) WEEKDAY="星期三" ;;
    4) WEEKDAY="星期四" ;;
    5) WEEKDAY="星期五" ;;
    6) WEEKDAY="星期六" ;;
    7) WEEKDAY="星期日" ;;
    *) WEEKDAY="" ;;
esac

# ---------- 2. 电量 ----------
BATTERY="未知"
if [ -r /sys/class/power_supply/battery/capacity ]; then
    BAT_VAL=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)
    if [ -n "$BAT_VAL" ]; then
        BATTERY="$BAT_VAL"
    fi
fi

# ---------- 3. WiFi 名称 ----------
WIFI_SSID="未连接"
WIFI_LINE=$(dumpsys wifi 2>/dev/null | grep -m1 "SSID:")
if [ -n "$WIFI_LINE" ]; then
    # 提取 SSID，去掉前后多余内容和引号
    EXTRACTED=$(echo "$WIFI_LINE" | sed 's/.*SSID: *//' | sed 's/[,\t ].*//' | tr -d '"')
    if [ -n "$EXTRACTED" ] && [ "$EXTRACTED" != "<unknown" ] && [ "$EXTRACTED" != "none" ] && [ "$EXTRACTED" != "" ]; then
        WIFI_SSID="$EXTRACTED"
    fi
fi

# ---------- 4. 音量 ----------
VOL_MUSIC=$(sos-settings-get system volume_music 2>/dev/null)
VOL_RING=$(sos-settings-get system volume_ring 2>/dev/null)
[ -z "$VOL_MUSIC" ] && VOL_MUSIC="未知"
[ -z "$VOL_RING" ] && VOL_RING="未知"

# ---------- 5. 组装并弹出通知 ----------
NOTIF_TITLE="开机信息提醒"
NOTIF_CONTENT="日期：${CURRENT_DATE} ${WEEKDAY}
时间：${CURRENT_TIME}
电量：${BATTERY}%
WiFi：${WIFI_SSID}
媒体音量：${VOL_MUSIC}
铃声音量：${VOL_RING}"

sos-notify "$NOTIF_TITLE" "$NOTIF_CONTENT"

sos-log "日期=$CURRENT_DATE 时间=$CURRENT_TIME 电量=${BATTERY}% WiFi=$WIFI_SSID 媒体音量=$VOL_MUSIC 铃声音量=$VOL_RING"
sos-log "===== 开机信息提醒完毕 ====="
