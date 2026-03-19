#!/bin/bash
set -e

FLUTTER_DIR="$HOME/flutter"

echo "==> Installing Flutter..."
git clone https://github.com/flutter/flutter.git --depth 1 --branch stable "$FLUTTER_DIR"

export PATH="$PATH:$FLUTTER_DIR/bin"

echo "==> Flutter version:"
flutter --version

echo "==> Getting dependencies..."
flutter pub get

echo "==> Building web..."
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=GOOGLE_WEB_CLIENT_ID="$GOOGLE_WEB_CLIENT_ID" \
  --dart-define=APP_ENVIRONMENT=production

echo "==> Build complete."
