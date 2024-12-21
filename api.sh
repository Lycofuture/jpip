#!/bin/bash
# 下载并解压 IP 文件
wget -q -O ips.zip https://zip.baipiao.eu.org
unzip -o ips.zip -d extracted

# 合并去重所有 IP 列表
find extracted -type f -name "*.txt" -exec cat {} + | sort -u > list.txt

# 清空旧的 *_ips.txt 文件
rm -f *_ips.txt

echo "正在查询 Zone ID..."
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN_NAME" \
-H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
-H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
-H "Content-Type: application/json" | jq -r '.result[0].id')
# 检查是否成功提取 Zone ID
if [[ -z "$ZONE_ID" ]]; then
  echo "未能获取 Zone ID，请检查你的域名或 API 密钥是否正确。"
  exit 1
else
  echo "成功获取 Zone ID"
fi

# 读取 IP 列表文件逐行处理
while read -r ip; do
    # 获取 IP 的地理位置信息
    response=$(curl -s -H "User-Agent: Mozilla/5.0" "https://api.ip.sb/geoip/$ip")
    geo=$(echo "$response" | jq -r '.country_code' 2>/dev/null || echo "ERROR")
    geo=$(echo "$geo" | tr '[:upper:]' '[:lower:]')  # 转换为小写
    country=$(echo "$response" | jq -r '.country' 2>/dev/null || echo "Unknown")

    if [ "$geo" != "ERROR" ] && [ -n "$geo" ]; then
        # 检查 IP 的 8443 端口是否开放
        if nc -z -w2 "$ip" 8443; then
            result="$ip"
            record="$ip:8443#$country"
            # 写入对应国家和综合文件
            echo "$record" >> "${geo}_ips.txt"
            echo "$record" >> all_ips.txt

            # 添加 DNS 记录到 Cloudflare
            #if [[ "$geo" == "hk" || "$geo" == "jp" || "$geo" == "us" ]]; then
                # 添加 DNS 记录到 Cloudflare
                dns_response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
                    -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
                    -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
                    -H "Content-Type: application/json" \
                    --data "{\"type\":\"A\",\"name\":\"$geo.$DOMAIN_NAME\",\"content\":\"$ip\",\"ttl\":1,\"proxied\":false}")

                # 检查 API 响应
                success=$(echo "$dns_response" | jq -r '.success' 2>/dev/null)
                if [ "$success" == "true" ]; then
                    echo "✅ 成功添加 $geo.$DOMAIN_NAME -> $ip" | tee -a cloudflare_log.txt
                else
                    error_message=$(echo "$dns_response" | jq -r '.errors[0].message' 2>/dev/null || echo "Unknown error")
                    echo "❌ 失败添加 $geo.$DOMAIN_NAME -> $ip: $error_message" | tee -a cloudflare_log.txt
                fi
          #  else
          #      echo "✋ 只为 HK、JP、US 添加 DNS 记录，跳过 $geo.$DOMAIN_NAME"
           # fi
        else
            echo "$ip:443 ❌ 端口关闭"
        fi
    else
        echo "$ip API 错误或无法获取地理信息"
    fi

    # 限制请求频率，避免 API 被封
    sleep 1
done < list.txt

echo "脚本处理完成。结果已保存到 *_ips.txt、all_ips.txt 和 cloudflare_log.txt 文件中。"
