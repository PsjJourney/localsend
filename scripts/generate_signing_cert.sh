#!/bin/bash
# ============================================
# 鸿蒙自签名证书生成脚本
# ============================================

set -e

# 配置信息
PASSWORD="123456"
KEY_ALIAS="debug"
VALIDITY=36500  # 100年
DNAME="CN=Test, OU=Test, O=Test, L=Test, ST=Test, C=CN"

# 输出目录
OUTPUT_DIR="app/ohos/sign"
mkdir -p "$OUTPUT_DIR"

echo "============================================"
echo "  生成鸿蒙自签名证书"
echo "============================================"

# 1. 生成 PKCS12 格式的密钥库
echo ">>> 1. 生成密钥库..."
keytool -genkeypair -alias "$KEY_ALIAS" \
  -keyalg EC \
  -keysize 256 \
  -validity "$VALIDITY" \
  -keystore "$OUTPUT_DIR/debug.p12" \
  -storetype PKCS12 \
  -storepass "$PASSWORD" \
  -keypass "$PASSWORD" \
  -dname "$DNAME"

# 2. 导出证书
echo ">>> 2. 导出证书..."
keytool -exportcert -alias "$KEY_ALIAS" \
  -keystore "$OUTPUT_DIR/debug.p12" \
  -storetype PKCS12 \
  -storepass "$PASSWORD" \
  -file "$OUTPUT_DIR/debug.cer"

# 3. 生成签名配置文件 (UnsgnedReleasedProfileTemplate.json)
echo ">>> 3. 生成签名配置..."
cat > "$OUTPUT_DIR/UnsgnedReleasedProfileTemplate.json" << 'EOF'
{
  "version-name": "1.0.0",
  "version-code": 1000000,
  "app-distribution-type": "os",
  "uuid": "PLACEHOLDER_UUID",
  "validity": {
    "not-before": 1672502400,
    "not-after": 4102444800
  },
  "keyalias": "debug",
  "bundle-info": {
    "developer-id": "PLACEHOLDER_DEVELOPER_ID",
    "distribution-certificate": "PLACEHOLDER_CERTIFICATE",
    "bundle-name": "com.localsend.localsend_app",
    "apl": "normal",
    "app-feature": "hos_normal_app"
  },
  "permissions": {
    "restricted-permissions": []
  },
  "issuer": "os"
}
EOF

# 4. 获取证书内容 (用于填充配置文件)
echo ">>> 4. 提取证书内容..."
CERT_CONTENT=$(keytool -printcert -file "$OUTPUT_DIR/debug.cer" | grep -A 100 "Certificate\[1\]:" | tail -n +2)

echo ""
echo "============================================"
echo "  证书生成完成！"
echo "============================================"
echo ""
echo "生成的文件："
echo "  - 密钥库: $OUTPUT_DIR/debug.p12"
echo "  - 证书:   $OUTPUT_DIR/debug.cer"
echo "  - 配置模板: $OUTPUT_DIR/UnsgnedReleasedProfileTemplate.json"
echo ""
echo "密码: $PASSWORD"
echo ""
echo "下一步："
echo "1. 登录 AppGallery Connect (AGC)"
echo "2. 创建项目和应用"
echo "3. 在'证书管理'中上传 debug.cer"
echo "4. 下载签名配置文件 (.p7b)"
echo "5. 将 .p7b 文件放到 $OUTPUT_DIR/ 目录"
echo ""
