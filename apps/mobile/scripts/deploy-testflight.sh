#!/bin/bash
set -e

# Load environment variables — look in script's parent dirs for .env
# scripts/ → mobile/ → apps/ → repo root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
if [ -f "$ENV_FILE" ]; then
  set -a; source "$ENV_FILE"; set +a
else
  echo "⚠️  No .env found at $ENV_FILE"
fi

# Validate required environment variables
if [ -z "$APPLE_API_KEY_PATH" ]; then
  echo "❌ Error: APPLE_API_KEY_PATH not set in .env"
  exit 1
fi

if [ -z "$APPLE_API_ISSUER_ID" ]; then
  echo "❌ Error: APPLE_API_ISSUER_ID not set in .env"
  exit 1
fi

if [ -z "$APPLE_APP_ID" ]; then
  echo "❌ Error: APPLE_APP_ID not set in .env"
  exit 1
fi

# Resolve APPLE_API_KEY_PATH to an absolute path
if [[ "$APPLE_API_KEY_PATH" != /* ]]; then
  APPLE_API_KEY_PATH="$REPO_ROOT/$APPLE_API_KEY_PATH"
fi

# Check if API key file exists
if [ ! -f "$APPLE_API_KEY_PATH" ]; then
  echo "❌ Error: API key file not found at $APPLE_API_KEY_PATH"
  exit 1
fi

# Extract the key ID from the filename (AuthKey_<ID>.p8 → <ID>)
KEY_FILENAME="$(basename "$APPLE_API_KEY_PATH")"
APPLE_API_KEY_ID="${KEY_FILENAME#AuthKey_}"
APPLE_API_KEY_ID="${APPLE_API_KEY_ID%.p8}"

# altool searches for the .p8 in ~/.appstoreconnect/private_keys/ — copy it there
PRIVATE_KEYS_DIR="$HOME/.appstoreconnect/private_keys"
mkdir -p "$PRIVATE_KEYS_DIR"
cp "$APPLE_API_KEY_PATH" "$PRIVATE_KEYS_DIR/AuthKey_${APPLE_API_KEY_ID}.p8"

# Find the IPA file
IPA_FILE=$(find build/ios/ipa -name "*.ipa" -type f | head -1)

if [ -z "$IPA_FILE" ]; then
  echo "❌ Error: No IPA file found in build/ios/ipa/"
  echo "Run 'flutter build ipa' first"
  exit 1
fi

echo "📤 Uploading IPA to TestFlight via Transporter..."
echo "   IPA: $IPA_FILE"
echo "   Key ID: $APPLE_API_KEY_ID"
echo "   App ID: $APPLE_APP_ID"

xcrun altool --upload-app \
  --type ios \
  --file "$(pwd)/$IPA_FILE" \
  --apiKey "$APPLE_API_KEY_ID" \
  --apiIssuer "$APPLE_API_ISSUER_ID"

if [ $? -eq 0 ]; then
  echo "✅ IPA successfully uploaded to TestFlight!"
else
  echo "❌ Upload failed. Check your credentials and try again."
  exit 1
fi
