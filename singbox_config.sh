#!/bin/bash
set -e
if ! which sing-box &> /dev/null; then
	if [[ $(uname -m) == x86_64 ]]; then
		wget https://github.com/SagerNet/sing-box/releases/download/v1.12.12/sing-box-1.12.12-linux-amd64.tar.gz
		tar -xf sing-box-1.12.12-linux-amd64.tar.gz
		mv ./sing-box-1.12.12-linux-amd64/sing-box /usr/local/bin
		rm -rf sing-box-1.12.12-linux-amd64 sing-box-1.12.12-linux-amd64.tar.gz
	fi
fi

default_config='  "outbounds": [
    {
      "type": "direct",
      "tag": "direct-out"
    },
    {
      "type": "shadowsocks",
      "tag": "ss-out",
      "server": "",
      "server_port": 5535,
      "method": "aes-128-gcm",
      "password": "xMUPk/K+LvP/YB95tlYqQInQzy/XSO2a26w0nX8weCA="
    }
  ],
  "route": {
    "rules": [
      {
        "rule_set": [
          "Tiktok",
          "Netflix",
          "Gemini",
          "OpenAi"
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
      },
      {
        "type": "remote",
        "tag": "OpenAi",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/senshinya/singbox_ruleset/main/rule/OpenAI/OpenAI.srs",
        "update_interval": "168h0m0s"
      }
    ],
    "final": "direct-out"
  }'

enable_bbr(){
	sed -i 's/.*net.core.default_qdisc.*//' /etc/sysctl.conf
	sed -i 's/.*net.ipv4.tcp_congestion_control.*//' /etc/sysctl.conf
	cat << 'eof' >> /etc/sysctl.conf
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
eof
	sudo sysctl -p &> /dev/null
}

appli(){
	apt update
	curl https://get.acme.sh | sh; apt install socat -y || yum install socat -y; ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
	~/.acme.sh/acme.sh --issue -d $server_name --standalone -k ec-256 --force --insecure
	~/.acme.sh/acme.sh --install-cert -d $server_name --ecc --key-file ~/certificate/server.key --fullchain-file ~/certificate/server.crt
}

vless(){
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
          "uuid": "$uuid"
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
          "private_key": "$private_key",
          "short_id": "$short_id",
          "max_time_difference": "1m0s"
        }
      }
    }
  ],
  $default_config
}
eof
	sing-box -D ~/singbox check &> /dev/null
	echo "This is your subscribe: vless://${uuid}@$(curl ifconfig.me):443?encryption=none&security=reality&sni=tesla.com&fp=edge&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none#$2"
}

tuic(){
	uuid=$(sing-box generate uuid)

	passwd=$(sing-box generate rand 12 --base64)
	mkdir -p ~/singbox ~/certificate

	if [[ ! -f ~/certificate/server.crt && ! -f ~/certificate/server.key ]]; then
		appli
	fi

	enable_bbr
	
	cat << eof > ~/singbox/config.json
{
  "inbounds": [
    {
	  "type": "tuic",
	  "tag": "tuic-in",
	
      "listen": "::",
      "listen_port": 443,
      "tcp_fast_open": true,
      "tcp_multi_path": true,
	
	  "users": [
	    {
	      "name": "lagsuc",
	      "uuid": "$uuid",
	      "password": "$passwd"
	    }
	  ],
	  "congestion_control": "bbr",
	  "auth_timeout": "3s",
	  "zero_rtt_handshake": false,
	  "heartbeat": "10s",
	  "tls": {
	  	"enabled": true,
	  	"server_name": "$server_name",
	  	"alpn": ["h3"],
	  	"certificate_path": "/root/certificate/server.crt",
	  	"key_path": "/root/certificate/server.key"
	  }
	}
  ],
  $default_config
}
eof
	sing-box -D ~/singbox check &> /dev/null
	echo "This is your subscribe: tuic://${uuid}:${passwd}@$(curl ifconfig.me):443?sni=$server_name&alpn=h3&congestion_control=bbr#$3"
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
	sudo systemctl stop sing-box || sudo systemctl start sing-box
}

while getopts "s:" opt; do
	case $opt in
		s)
			server_name=$OPTARG
			;;
		\?)
			echo "Unkonw args"
			exit 1
			;;
			
	esac
done

shift $((OPTIND - 1))

$1 $2

using_systemd
