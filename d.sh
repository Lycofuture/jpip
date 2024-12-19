# Cloudflare API 信息
CLOUDFLARE_EMAIL="d342jxc@gmail.com"
CLOUDFLARE_API_KEY="6dc09676275e94479ec8bab58d508804e083c"
DOMAIN_NAME="misakanetwork.us.kg"
# 查询 Zones 列表
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
  echo "成功获取 Zone ID: $ZONE_ID"
fi

# 删除所有 DNS 记录，直到清空
while :; do
  echo "查询当前 DNS 记录..."
  dns_records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?page=1&per_page=100" \
  -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
  -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
  -H "Content-Type: application/json")

  # 提取当前记录 ID 数量
  record_ids=$(echo "$dns_records" | jq -r '.result[].id')
  # 统计数量
  record_count=$(echo "$record_ids" | grep -c '[^[:space:]]')

  if [[ $record_count -eq 0 ]]; then
    echo "所有 DNS 记录已清空。"
    break
  fi

  echo "当前 DNS 记录数: $record_count"

  # 删除每条记录
  for record_id in $record_ids; do
    echo "尝试删除记录 ID: $record_id"
    response=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
    -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
    -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
    -H "Content-Type: application/json")

    if [[ $(echo "$response" | jq -r '.success') == "true" ]]; then
      echo "成功删除记录 ID: $record_id"
    else
      echo "删除记录 ID: $record_id 失败 - $(echo "$response" | jq -r '.errors')"
      echo "重试删除记录 ID: $record_id..."
      retry_response=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
      -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
      -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
      -H "Content-Type: application/json")

      if [[ $(echo "$retry_response" | jq -r '.success') == "true" ]]; then
        echo "重试成功删除记录 ID: $record_id"
      else
        echo "重试仍然失败，稍后继续尝试。"
      fi
    fi
  done
done

echo "DNS 记录清理完成。"