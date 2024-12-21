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

# 删除所有 A 类型 DNS 记录
page=1
while :; do
  echo "查询第 $page 页的 DNS 记录..."
  dns_records=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?page=$page&per_page=100" \
  -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
  -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
  -H "Content-Type: application/json")

  # 提取 A 类型记录的 ID 和名称
  record_ids=$(echo "$dns_records" | jq -r '.result[] | select(.type == "A") | "\(.id) \(.name)"')

  # 如果没有更多 A 记录，则退出循环
  if [[ -z "$record_ids" ]]; then
    echo "第 $page 页无 A 类型记录，清理完成。"
    break
  fi

  echo "找到以下 A 类型记录："
  echo "$record_ids" | awk '{print $2}'

  # 删除每条 A 类型记录
  while read -r record_id record_name; do
    response=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
    -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
    -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
    -H "Content-Type: application/json")

    if [[ $(echo "$response" | jq -r '.success') == "true" ]]; then
      echo "成功删除记录: $record_name (ID: $record_id)"
    else
      echo "删除记录失败: $record_name (ID: $record_id) - $(echo "$response" | jq -r '.errors')"
      echo "重试删除记录..."
      retry_response=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
      -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
      -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
      -H "Content-Type: application/json")

      if [[ $(echo "$retry_response" | jq -r '.success') == "true" ]]; then
        echo "重试成功删除记录: $record_name (ID: $record_id)"
      else
        echo "重试仍然失败，跳过此记录。"
      fi
    fi
  done <<< "$record_ids"

  ((page++))
done

echo "A 类型 DNS 记录清理完成。"
