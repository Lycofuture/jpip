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

# 添加 DNS 记录
echo "添加解析"
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
-H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
-H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
-H "Content-Type: application/json" \
--data '{"type":"A","name":"aa.misakanetwork.us.kg","content":"114.114.1.0","ttl":1,"proxied":false}'