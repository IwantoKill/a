#!/bin/bash
set -e
if ! which sing-box; then
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
	  	"uuid": "$uuid"
        }
      ],
      "tls": {
        "enabled": true,
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "tesla.com",
            "server_port": 443
          },
	  "private_key": "$private_key",
          "short_id": [
            "$short_id"
          ],
          "max_time_difference": "1m"
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct-out"
    }
  ]
}
eof
	sing-box -D ~/singbox check &> /dev/null
	echo "This is your subscribe: vless://${uuid}@$(curl ifconfig.me):443?encryption=none&security=reality&sni=tesla.com&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none#$1"
}

make_config $1
