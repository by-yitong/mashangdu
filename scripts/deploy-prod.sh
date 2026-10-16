#!/usr/bin/env bash
# 部署到线上环境（103.117.137.83，systemd 系统服务，端口 8091）。
# 对外访问地址 https://studio.phpcurl.cn/ （nginx 反代由运维侧配置，脚本不碰）。
# 流程与 deploy-dev 相同：构建 admin → 嵌入 → 交叉编译 → 上传 → 替换重启 → 验证。
# 用法：bash scripts/deploy-prod.sh
set -euo pipefail

HOST=root@103.117.137.83
REMOTE_DIR=/opt/code-tutorials
PORT=8091

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
systemctl restart code-tutorials.service
sleep 2
systemctl is-active code-tutorials.service
curl -s 127.0.0.1:$PORT/api/v1/meta
"
echo
echo "线上部署完成：http://103.117.137.83:$PORT （对外 https://studio.phpcurl.cn/ ，后台 /admin/）"
