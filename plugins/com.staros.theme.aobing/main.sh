#!/system/bin/sh
##########################################################################
# 敖丙星空主题 · Star OS 插件(com.staros.theme.aobing)
#
# 干的事只有一件:把主题包(星轨表盘 + 星空壁纸 + 图标包)注入到主题模块的
# 目录里,让「个性主题」和表盘列表里多出一套敖丙星空。
#
# 为什么插件本体这么小:
#   主题包原始体积约 14 MB、253 个文件,里面还含表盘插件包(本质是个 APK);
#   而插件包上限 1 MB / 200 个文件,并明令禁止携带任何二进制。
#   所以走「云端取包 + 本地注入」这条路:插件本体只有文本脚本,能逐行审。
#
# 申请权限(为什么一个都不能少):
#   shell   —— Android 8.1 没有 unzip,得用 Magisk 自带的 busybox 解压,
#              而 /data/adb 只有 root 读得到;写内部存储也要 root 才稳;
#   network —— 从 GitHub 取主题包(4 个镜像轮流试);
#   notify  —— 过程提示。手表就一块小屏,不弹提示用户会以为卡死。
#
# 数据位置:/data/adb/star_os/plugins/com.staros.theme.aobing/data/
#   payload.zip     下载下来的主题包(sha256 对得上才会用)
#   backup/latest/  注入前的原主题(卸载时用来还原)
#   applied.conf    注入记录
#
# 还原:卸载插件会自动跑 uninstall 钩子还原;也可以手动以 root 身份跑
#   sh /data/adb/modules/zz_star_os/plugin_exec.sh run com.staros.theme.aobing uninstall
##########################################################################

PID_="com.staros.theme.aobing"
PDIR_="${SOS_DIR:-/data/adb/star_os/plugins/$PID_}"
SDIR_="${SOS_SRC:-$PDIR_/src}"
DDIR_="${SOS_DATA:-$PDIR_/data}"
HOOK_="${SOS_HOOK:-manual}"
CONF_="$SDIR_/res/payload.conf"

# 主题模块(ThemePro)读取的目录 —— 和主题模块、刷入脚本写的是同一个地方
THEME_THEME="theme_pack/aobing"
THEME_CL="dial/aobing.cl"
THEME_RESS="dial/res/aobing"

T() { echo "[主题] $*"; }
say() { T "$*"; sos-notify "敖丙星空主题" "$1" >/dev/null 2>&1; }
die() { T "错误: $1"; say "$1"; exit 1; }

# ------------------------------------------------------------------ 工具探测
# ⚠ 插件执行时 PATH 被收窄成「包装命令 + /system/bin:/system/xbin」,
#   Magisk 的 busybox 不在 PATH 里,必须用绝对路径找(和 8.1 没有 awk 同源的坑)。
PE_BB=""
for pe_bb_p in /data/adb/magisk/busybox /sbin/.magisk/busybox \
               /data/adb/ksu/bin/busybox /system/xbin/busybox /system/bin/busybox; do
  if [ -x "$pe_bb_p" ]; then PE_BB="$pe_bb_p"; break; fi
done
[ -n "$PE_BB" ] || PE_BB="$(command -v busybox 2>/dev/null)"

pe_sha() {
  # $1 = 文件 → 输出 sha256(拿不到就输出空)
  # 收尾统一「去反斜杠 + 取前 64 位」:GNU 版 sha256sum 遇到文件名里有反斜杠
  # 会在行首加一个转义符(电脑上测的时候踩到),这里一并吃掉,只认那 64 位。
  pe_sh_o=""
  if command -v sha256sum >/dev/null 2>&1; then
    pe_sh_o="$(sha256sum "$1" 2>/dev/null)"
  elif [ -n "$PE_BB" ]; then
    pe_sh_o="$("$PE_BB" sha256sum "$1" 2>/dev/null)"
  fi
  printf '%s' "$pe_sh_o" | tr -d '\\' | cut -c1-64
}

pe_unzip() {
  # $1 = zip,$2 = 目标目录
  if command -v unzip >/dev/null 2>&1; then
    unzip -o "$1" -d "$2" >> "$DDIR_/unzip.log" 2>&1
  elif [ -n "$PE_BB" ]; then
    "$PE_BB" unzip -o "$1" -d "$2" >> "$DDIR_/unzip.log" 2>&1
  else
    return 1
  fi
}

pe_bytes() {
  # $1 = 文件 → 字节数(空/不存在输出 0)
  [ -f "$1" ] || { echo 0; return; }
  wc -c < "$1" 2>/dev/null | tr -d ' \n'
}

# ------------------------------------------------------------------ 读配置
pe_val() {
  # $1 = 键名。用 sed 取(Android 8.1 没有 awk,别用)
  sed -n "s/^$1=//p" "$CONF_" 2>/dev/null | head -n 1
}

# ------------------------------------------------------------------ 权限自检
case ",${SOS_PERMS:-}," in
  *",shell,"*) ;;
  *) die "缺「shell」权限 —— 请在 插件中心 → 已安装 → 敖丙星空主题 → 权限 里勾上(红色高风险项),再运行一次。" ;;
esac

# ------------------------------------------------------------------ 目标目录
# 正常情况自动探测手表内部存储;THEME_SD_ROOT 是给「非标准 ROM / 电脑上干跑
# 测试」留的覆盖开关,留空就用自动探测的结果。
PE_SD="${THEME_SD_ROOT:-}"
if [ -z "$PE_SD" ]; then
  for pe_sd_p in /sdcard /storage/emulated/0 /data/media/0; do
    if [ -d "$pe_sd_p/Android" ]; then PE_SD="$pe_sd_p"; break; fi
  done
fi
[ -n "$PE_SD" ] || die "找不到内部存储,无法注入主题。"
TARGET_="$PE_SD/Android/baiyao105/ThemePro/Themes"

# ------------------------------------------------------------------ 备份/还原
pe_backup() {
  [ -d "$DDIR_/backup/latest" ] && { T "已有原始备份,跳过备份。"; return 0; }
  pe_bk_n=0
  mkdir -p "$DDIR_/backup/latest" 2>/dev/null
  for pe_bk_p in "$THEME_THEME" "$THEME_CL" "$THEME_RESS"; do
    if [ -e "$TARGET_/$pe_bk_p" ]; then
      mkdir -p "$DDIR_/backup/latest/$(dirname "$pe_bk_p")" 2>/dev/null
      cp -r "$TARGET_/$pe_bk_p" "$DDIR_/backup/latest/$pe_bk_p" 2>/dev/null \
        && pe_bk_n=$((pe_bk_n + 1))
    fi
  done
  T "已备份 $pe_bk_n 项原主题到 $DDIR_/backup/latest"
}

pe_restore() {
  if [ ! -d "$DDIR_/backup/latest" ]; then
    T "没有安装前的备份 —— 不动任何文件(免得误删你自己的主题)。"
    say "已卸载,主题文件未改动。"
    return 0
  fi
  pe_rs_n=0
  for pe_rs_p in "$THEME_THEME" "$THEME_CL" "$THEME_RESS"; do
    if [ -e "$DDIR_/backup/latest/$pe_rs_p" ]; then
      rm -rf "$TARGET_/$pe_rs_p" 2>/dev/null
      mkdir -p "$TARGET_/$(dirname "$pe_rs_p")" 2>/dev/null
      cp -r "$DDIR_/backup/latest/$pe_rs_p" "$TARGET_/$pe_rs_p" 2>/dev/null \
        && pe_rs_n=$((pe_rs_n + 1))
    fi
  done
  T "已还原 $pe_rs_n 项。"
  say "已还原安装前的主题。"
}

# ------------------------------------------------------------------ 取包
PE_SIZE="$(pe_val SIZE)"
PE_SHA="$(pe_val SHA256)"
PE_ZIP="$DDIR_/payload.zip"

pe_ready() {
  # 本地已有一份校验过的包就不用再下
  [ -f "$PE_ZIP" ] || return 1
  [ "$(pe_bytes "$PE_ZIP")" = "$PE_SIZE" ] || return 1
  [ "$(pe_sha "$PE_ZIP")" = "$PE_SHA" ] || return 1
  return 0
}

pe_download() {
  pe_dl_i=1
  while [ "$pe_dl_i" -le 4 ]; do
    pe_dl_u="$(pe_val "URL$pe_dl_i")"
    pe_dl_i=$((pe_dl_i + 1))
    [ -n "$pe_dl_u" ] || continue
    T "下载主题包(镜像 $((pe_dl_i - 1))):$pe_dl_u"
    rm -f "$DDIR_/payload.part" 2>/dev/null
    sos-http "$pe_dl_u" "$DDIR_/payload.part" || { T "  这个镜像没通,换下一个"; continue; }
    pe_dl_sz="$(pe_bytes "$DDIR_/payload.part")"
    T "  下到 $pe_dl_sz / $PE_SIZE 字节"
    if [ "$pe_dl_sz" != "$PE_SIZE" ]; then
      T "  大小对不上,换下一个镜像"
      continue
    fi
    pe_dl_h="$(pe_sha "$DDIR_/payload.part")"
    if [ -z "$PE_SHA" ] || [ "$pe_dl_h" = "$PE_SHA" ]; then
      mv -f "$DDIR_/payload.part" "$PE_ZIP" 2>/dev/null
      T "  校验通过"
      return 0
    fi
    T "  sha256 不一致,丢弃这个镜像"
  done
  return 1
}

# ------------------------------------------------------------------ 注入
pe_apply() {
  say "正在注入主题…"
  mkdir -p "$TARGET_" 2>/dev/null
  pe_unzip "$PE_ZIP" "$TARGET_" || die "解压失败 —— 本机既没有 unzip 也没有可用的 busybox。"
  for pe_ap_f in "$THEME_CL" "$THEME_THEME/config.json" \
                 "$THEME_THEME/dial/aobing.cl" "$THEME_THEME/icons/config.json"; do
    [ -f "$TARGET_/$pe_ap_f" ] || die "注入后缺少文件:$pe_ap_f(包可能不完整)"
  done
  # 桌面图标包是给主题模块读的,顺便把时间戳刷新一下,免得它用缓存
  date '+%Y-%m-%d %H:%M:%S' > "$DDIR_/applied.conf" 2>/dev/null
  pe_ap_n=$(ls "$TARGET_/$THEME_THEME/icons" 2>/dev/null | wc -l | tr -d ' \n')
  T "注入完成:$pe_ap_n 个图标 + 表盘 + 壁纸 → $TARGET_"
}

# ------------------------------------------------------------------ 主流程
T "================ 敖丙星空主题 ================"
T "插件 : $PID_"
T "钩子 : $HOOK_"
T "身份 : $(id -u 2>/dev/null) · 权限:[${SOS_PERMS:-无}]"
T "目标 : $TARGET_"

case "$HOOK_" in
  uninstall)
    pe_restore
    exit 0
    ;;
esac

if [ ! -d "$PE_SD/Android/baiyao105/ThemePro" ]; then
  T "提示:没检测到主题模块(ThemePro)的目录,文件会先放好,装好主题模块就能用。"
fi

if pe_ready; then
  T "本地已有主题包(校验通过),跳过下载。"
else
  say "开始下载主题包(约 14 MB,请连 WiFi)…"
  pe_download || die "4 个镜像都没下成功 —— 检查一下网络,或者稍后再点一次「运行」重试。"
fi

pe_backup
pe_apply

T "全部完成。"
say "主题已就绪 —— 到「个性主题」里应用敖丙,表盘列表里选星轨那款。"
exit 0
