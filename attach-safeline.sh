#!/usr/bin/env bash
# 把 wb-proxy 接进雷池的 docker 网络，并验证雷池能打到它
# 用法：sudo bash attach-safeline.sh
# 可选：APP_DIR=/opt/wb2api  TENGINE=safeline-tengine
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/wb2api}"
COMPOSE="$APP_DIR/docker-compose.yml"
TENGINE="${TENGINE:-safeline-tengine}"

info() { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "请用 root 运行"
[ -f "$COMPOSE" ] || die "找不到 $COMPOSE（先放好 docker-compose.yml）"

# 1) 找网络
NETS=$(docker network ls --format '{{.Name}}' | grep -i safeline || true)
[ -n "$NETS" ] || die "没找到雷池网络，先安装雷池（setup.sh）"
NET=$(printf '%s\n' "$NETS" | head -n1)
[ "$(printf '%s\n' "$NETS" | wc -l)" -gt 1 ] && warn "匹配到多个网络：$(echo $NETS)，取 $NET"
info "雷池网络：$NET"

# 2) 确认 tengine 在网络上
docker inspect "$TENGINE" \
  -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null \
  | tr ' ' '\n' | grep -qx "$NET" \
  || warn "$TENGINE 不在 $NET 上，下面连通性测试大概率失败"

# 3) 改 compose 里的网络名
sed -i "s/^\([[:space:]]*name:[[:space:]]*\).*safeline.*$/\1$NET/" "$COMPOSE"
grep -q "name: $NET" "$COMPOSE" || die "compose 改名失败，请手动把 networks.safeline.name 改成 $NET"
info "已把 compose 的 external 网络名改为 $NET"

# 4) 重启网关（只重建容器，不动数据）
cd "$APP_DIR"
docker compose up -d
info "等待容器 healthy"
for i in $(seq 1 30); do
  st=$(docker inspect -f '{{.State.Health.Status}}' wb-proxy 2>/dev/null || echo unknown)
  [ "$st" = "healthy" ] && break
  sleep 2
done

# 5) 从雷池侧验证
info "从 $TENGINE 探测 http://wb-proxy:8788/health"
if docker exec "$TENGINE" wget -qO- --timeout=3 http://wb-proxy:8788/health 2>/dev/null; then
  echo
  info "连通 OK —— 雷池站点「上游服务器」填：http://wb-proxy:8788"
else
  echo
  warn "连通失败。备选方案：把 compose ports 改成 \"172.17.0.1:8788:8788\"，"
  warn "docker compose up -d 后，上游改填 http://172.17.0.1:8788"
  warn "（docker0 地址：$(ip -4 addr show docker0 2>/dev/null | grep -oP 'inet \K[\d.]+' || echo 未找到)）"
  exit 1
fi
