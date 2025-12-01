#!/bin/bash
set -e
if ! which sing-box &> /dev/null; then
	if [[ $(uname -m) == x86_64 ]]; then
		wget https://github.com/SagerNet/sing-box/releases/download/v1.12.12/sing-box-1.12.12-linux-amd64.tar.gz
		tar -xf sing-box-1.12.12-linux-amd64.tar.gz
		mv ./sing-box-1.12.12-linux-amd64/sing-box /usr/local/bin
		rm -rf sing-box-1.12.12-linux-amd64
	fi
fi

make_config(){
	uuid=$(sing-box generate uuid)
	generate=$(sing-box generate reality-keypair)
	private_key=$(echo "$generate" | awk '/PrivateKey/ {print $2}')
	public_key=$(echo "$generate" | awk '/PublicKey/ {print $2}')
	short_id=$(sing-box generate rand 8 --hex)
	mkdir -p ~/singbox
	cat << eof > ~/singbox/config.json
{
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": 443,
      "tcp_fast_open": true,
      "tcp_multi_path": true,
      "users": [
        {
          "name": "lagsuc",
          "uuid": "513aa585-097c-40db-b04a-674794d3a9ac"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "tesla.com",
        "alpn": [
          "h1",
          "h2"
        ],
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "tesla.com",
            "server_port": 443
          },
          "private_key": "uOrUMe-vFx2wYf3wVctS22f9o_ClxNPBOZMNES-tmH4",
          "short_id": "6db2626f2db6e090",
          "max_time_difference": "1m0s"
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct-out"
    },
    {
      "type": "shadowsocks",
      "tag": "ss-out",
      "server": "1.22.33.48",
      "server_port": 65535,
      "method": "aes-128-gcm",
      "password": "xMUPk/K+LvP/YB95tlYqQInQzy/XSO2a26w0nX8weCA="
    }
  ],
  "route": {
    "rules": [
      {
        "inbound": "vless-in",
        "rule_set": [
          "Tiktok",
          "Netflix",
          "Gemini"
        ],
        "outbound": "ss-out"
      }
    ],
    "rule_set": [
      {
        "type": "remote", // or source
        "tag": "Tiktok",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/senshinya/singbox_ruleset/main/rule/TikTok/TikTok.srs",
        "update_interval": "168h0m0s"
      },
      {
        "type": "remote",
        "tag": "Netflix",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/senshinya/singbox_ruleset/main/rule/Netflix/Netflix.srs",
        "update_interval": "168h0m0s"
      },
      {
        "type": "remote",
        "tag": "Gemini",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/senshinya/singbox_ruleset/main/rule/Gemini/Gemini.srs",
        "update_interval": "168h0m0s"
      }
    ],
    "final": "direct-out"
  }
}
eof
	sing-box -D ~/singbox check &> /dev/null
	echo "This is your subscribe: vless://${uuid}@$(curl ifconfig.me):443?encryption=none&security=reality&sni=tesla.com&fp=edge&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none#$1"
}

using_systemd(){
	cat << 'eof' > /etc/systemd/system/sing-box.service
[Unit]
Description=Sing-box Service
Documentation=https://sing-box.sagernet.org/
After=network.target nss-lookup.target

[Service]
Type=simple
# 根据你的实际路径修改，可执行文件一般在 /usr/local/bin 或 /usr/bin
ExecStart=/usr/local/bin/sing-box run -c /root/singbox/config.json

# 建议启用以下增强安全性的设置（可按需开启/禁用）
#CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
#AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true

# 崩溃后自动重启
Restart=on-failure
RestartSec=5

# 资源限制（可选）
LimitNOFILE=65535

# 运行用户（可选，如果你已有 singbox 用户）
#User=singbox
#Group=singbox

[Install]
WantedBy=multi-user.target
eof

	sudo systemctl daemon-reload
	sudo systemctl enable sing-box
	sudo systemctl start sing-box
}

make_config $1

using_systemd
