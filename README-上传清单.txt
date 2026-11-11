WorkBuddy2API-Hub + 雷池 WAF —— 上传清单
==========================================
本文件夹里 5 个文件，只有 4 个要传；传完按下面落点放好即可。

──────────────────────────────────────────
1) docker-compose.yml
   落点：/opt/wb2api/docker-compose.yml
   作用：网关容器，只绑 127.0.0.1:8788，并接入雷池 docker 网络
   注意：起之前先查网络名，改文件里的 networks.safeline.name
         docker network ls --format '{{.Name}}' | grep -i safeline

2) attach-safeline.sh
   落点：/opt/wb2api/attach-safeline.sh
   用法：cd /opt/wb2api && sudo bash attach-safeline.sh
   作用：自动找雷池网络 → 改 compose → 重启网关 → 从 tengine 容器里探测 /health
   报错 "Permission denied" 或 "bad interpreter" 时先转一下换行：
         sed -i 's/\r$//' attach-safeline.sh && chmod +x attach-safeline.sh

3) safeline-backend.conf
   落点：先放 /root/safeline-backend.conf，再复制进雷池配置目录：
         cp /root/safeline-backend.conf \
            /data/safeline/resources/nginx/custom_params/backend_<ID>
         docker exec safeline-tengine nginx -t
         docker exec safeline-tengine nginx -s reload
   说明：<ID> 用 ls /data/safeline/resources/nginx/custom_params/ 看已有文件名
         （该目录为空 = 还没建站点，先在雷池面板把站点加好再回来）
         这个文件负责关掉 SSE 缓冲、把超时拉到 3600s

4) 部署说明-雷池版.md
   落点：/root/ 即可（服务器上用 less 看，或留着自己对照）
   内容：装雷池、加站点、放行 /v1、排错表、安全清单

5) README-上传清单.txt（本文件，不用上传）

──────────────────────────────────────────
不需要上传的
  accounts/  usage/  subbridge-data/
      → 服务器上 docker compose 会自动创建，是持久化数据卷
  Caddyfile / wb2api.nginx.conf / deploy.sh
      → 那是 Nginx/Caddy 方案，走雷池用不到

上传方式（任选）
  # 先在服务器建目录
  ssh root@<服务器IP> "mkdir -p /opt/wb2api/{accounts,usage,subbridge-data}"

  # 从本文件夹所在目录执行
  scp docker-compose.yml attach-safeline.sh root@<服务器IP>:/opt/wb2api/
  scp safeline-backend.conf 部署说明-雷池版.md root@<服务器IP>:/root/

  Windows 也可以用 WinSCP / MobaXterm / Xftp 直接拖拽。

──────────────────────────────────────────
上传后的执行顺序
  1. 装雷池：bash -c "$(curl -fsSLk https://waf-ce.chaitin.cn/release/latest/setup.sh)"
     登录 https://<服务器IP>:9443/ （账号 admin，密码看安装输出），改强口令
  2. 起网关：cd /opt/wb2api && sudo bash attach-safeline.sh
     看到 "连通 OK" 才算过；没通就按脚本提示走 172.17.0.1 兜底方案
  3. 雷池面板加站点 api.example.com：443 + SSL 证书 + 上游 http://wb-proxy:8788
  4. 雷池「规则」加自定义规则：URL ^/v1/ → 放行
  5. 放 safeline-backend.conf（上面第 3 条），nginx -t + reload
  6. 本机 ssh -N -L 8788:127.0.0.1:8788 root@<IP>，浏览器开 http://127.0.0.1:8788/
     改看板密码 → 加账号(OAuth) → 建 API Key
  7. 公网验证：
     curl -N https://api.example.com/v1/chat/completions \
       -H "Authorization: Bearer <KEY>" -H 'Content-Type: application/json' \
       -d '{"model":"deepseek-v4.1-flash","stream":true,"messages":[{"role":"user","content":"数到50"}]}'
     要看到 data 块一块块出来。

──────────────────────────────────────────
安全组只需开：22、80、443；9443 只对自己的 IP 开；8788 永远不开。
