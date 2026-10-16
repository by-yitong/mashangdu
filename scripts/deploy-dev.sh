#!/usr/bin/env bash
# 部署到 dev 环境（192.168.31.169，飞牛 NAS，systemd 用户服务，端口 8090）。
# 流程：构建 admin → 嵌入 backend/web/dist → 交叉编译 linux 二进制
#       → 连同 seeddata/static 打包上传 → 替换并重启服务 → 验证。
# 用法：bash scripts/deploy-dev.sh   （在仓库根目录或任意目录执行均可）
set -euo pipefail

HOST=admins@192.168.31.169
REMOTE_DIR=/home/1944876825/code-tutorials
PORT=8090

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "==> [1/5] 构建 admin 前端"
cd "$ROOT/admin" && npm run build

echo "==> [2/5] 嵌入前端产物到 backend/web/dist"
rm -rf "$ROOT/backend/web/dist"
cp -r "$ROOT/admin/dist" "$ROOT/backend/web/dist"

echo "==> [3/5] 交叉编译 linux/amd64"
cd "$ROOT/backend" && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o backend-linux .

echo "==> [4/5] 上传（二进制 + seeddata + static）"
tar czf /tmp/ct-deploy.tar.gz -C "$ROOT/backend" backend-linux static -C "$ROOT/backend/internal/store" seeddata
scp -q /tmp/ct-deploy.tar.gz "$HOST":/tmp/

echo "==> [5/5] 替换并重启服务"
ssh "$HOST" "
set -e
cd $REMOTE_DIR
mkdir -p .stage && tar xzf /tmp/ct-deploy.tar.gz -C .stage
rm -f backend-linux && mv .stage/backend-linux backend-linux && chmod +x backend-linux
cp -r .stage/seeddata/. seeddata/
cp -r .stage/static/. static/
rm -rf .stage /tmp/ct-deploy.tar.gz
export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
systemctl --user restart code-tutorials.service
sleep 2
systemctl --user is-active code-tutorials.service
curl -s 127.0.0.1:$PORT/api/v1/meta
"
echo
echo "dev 部署完成：http://192.168.31.169:$PORT （后台 /admin/，已嵌入登录页）"
