# install_singbox_acme_fixed.sh — 使用说明（示例参数）

这是一个 **非交互式** 的一键安装脚本，用于在 Linux / 容器 环境上快速部署 `sing-box`，支持自动尝试 ACME（acme.sh / certbot），并在完成后输出一键导入链接并保存到环境变量文件。

## 文件
- `install_singbox_acme_fixed.sh` — 主脚本（保存并 `chmod +x`）
- `/etc/sing-box/config.json` — 生成的 sing-box 配置
- `/etc/sing-box/client_info.txt` — 可读的客户端导入信息
- `/etc/profile.d/singbox_env.sh` — 导入后可用的环境变量（`SINGBOX_CONN`）

## 运行要求
- 以 `root` 或 `sudo` 运行（需要写 `/etc`、创建 systemd unit、安装包等）
- 如果启用 TLS 且希望使用 ACME（Let's Encrypt），脚本需能对外绑定端口 80（http-01 standalone），并且域名需要解析到服务器公网 IP
- 推荐安装 `curl`, `openssl`, `tar`, `wget` 等常用工具（脚本会尽力安装/回退）

## 支持协议
`--protocol` 参数（可选，默认 `vmess`）：
- `vmess` （**强制使用 ws 传输**；TLS 可选）
- `vless`
- `ss` （Shadowsocks）
- `tuic`

## 参数
- `--protocol <tuic|ss|vmess|vless>`（默认 `vmess`）
- `--domain <example.com>`（可选；用于 TLS/ACME 申请与客户端导入时的 host）
- `--tls true|false`（默认 `false`）
- `--port <port>`（可选；不填则使用合理默认，例如 vmess/vless 80（无 tls）或 443（tls））
- `--dns 1.1.1.1,8.8.4.4`（可选；用逗号分隔的 DNS 列表）

## 示例
1. vmess + TLS（尝试 ACME）：
```sh
sudo bash install_singbox_acme_fixed.sh --protocol vmess --domain example.com --tls true --port 443 --dns 1.1.1.1,8.8.4.4
