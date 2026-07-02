{
  "log": { "level": "warn", "timestamp": true },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": ${VLESS_PORT},
      "users": [],
      "tls": {
        "enabled": true,
        "server_name": "${REALITY_SNI}",
        "reality": {
          "enabled": true,
          "handshake": { "server": "${REALITY_SNI}", "server_port": 443 },
          "private_key": "${REALITY_PRIVATE_KEY}",
          "short_id": ["${REALITY_SHORT_ID}"]
        }
      }
    },
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": ${HY2_PORT},
      "up_mbps": ${HY2_UP_MBPS},
      "down_mbps": ${HY2_DOWN_MBPS},
      "users": [],
      "obfs": {
        "type": "salamander",
        "password": "${HY2_OBFS_PASS}"
      },
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "${SB_ROOT}/certs/cert.pem",
        "key_path": "${SB_ROOT}/certs/key.pem"
      }
    },
    {
      "type": "socks",
      "tag": "socks5-in",
      "listen": "0.0.0.0",
      "listen_port": ${SOCKS5_PORT},
      "users": []
    }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" }
  ],
  "route": {
    "rules": [
      { "action": "sniff" },
      { "ip_is_private": true, "action": "reject" }
    ],
    "final": "direct"
  }
}
