#!/bin/bash
set -e

FLUTTER_DIR="$HOME/flutter"

echo "==> Installing Flutter..."
git clone https://github.com/flutter/flutter.git --depth 1 --branch stable "$FLUTTER_DIR"

export PATH="$PATH:$FLUTTER_DIR/bin"

echo "==> Flutter version:"
flutter --version

echo "==> Creating required asset directories..."
mkdir -p assets/icons

echo "==> Generating assets/.env from Netlify environment..."
cat > assets/.env <<EOF
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
GOOGLE_WEB_CLIENT_ID=${GOOGLE_WEB_CLIENT_ID}
APP_ENVIRONMENT=production
DIRECT_ADS_ENABLED=true
MIN_CPM_RATE=1500
MIN_CPC_RATE=400
AD_FREQUENCY_FREE=5
AD_FREQUENCY_BASIC=10
SELCOM_BACKEND_URL=
APP_VERSION=1.0.0
API_TIMEOUT=30000
ENABLE_VIDEO_TOURS=true
ENABLE_VIRTUAL_TOURS=true
ENABLE_CHAT=true
ENABLE_NOTIFICATIONS=true
EOF

echo "==> Getting dependencies..."
flutter pub get

echo "==> Building web..."
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=GOOGLE_WEB_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID" \
  --dart-define=APP_ENVIRONMENT=production

echo "==> Build complete."
