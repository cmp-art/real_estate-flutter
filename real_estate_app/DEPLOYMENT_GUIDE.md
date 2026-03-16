# Real Estate App — Deployment Guide
## Play Store (Android) + Progressive Web App (PWA)

---

## PART 1 — PREREQUISITES (Do ONCE)

### 1.1 Install Required Tools
```bash
# Flutter SDK (already installed if you're building)
flutter --version   # must be >= 3.0.0

# Android Studio or just the CLI tools
# Download from: https://developer.android.com/studio

# Java Development Kit 17
# Download from: https://adoptium.net

# Node.js 18+ (for backend deploy)
node --version

# Google Play CLI (optional but useful)
# npm install -g google-play-cli
```

### 1.2 One-time Flutter setup check
```bash
flutter doctor -v
# Fix any red items before proceeding
```

---

## PART 2 — PREPARE YOUR APP FOR PRODUCTION

### 2.1 Update app version in pubspec.yaml
```yaml
version: 1.0.0+1   # format: human_version+build_number
# Increment build number every release: 1.0.0+1, 1.0.0+2, 1.0.1+3 ...
```

### 2.2 Update app bundle ID (package name)
Change from `com.example.real_estate_app` to your own:
```
android/app/build.gradle.kts → applicationId = "com.yourcompany.realestate"
```
Also update `android/app/src/main/AndroidManifest.xml` package attribute.

### 2.3 Add your real Supabase credentials
Edit `assets/.env`:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SELCOM_BACKEND_URL=https://your-backend.railway.app
```

### 2.4 Add your real app name and icons
- Replace `web/icons/Icon-192.png` and `Icon-512.png` with your real logo
- Replace `android/app/src/main/res/mipmap-*/` launcher icons
  ```bash
  # Easy way — use flutter_launcher_icons package:
  flutter pub add flutter_launcher_icons --dev
  # Add to pubspec.yaml assets section, then:
  flutter pub run flutter_launcher_icons
  ```
- Update app name in `android/app/src/main/AndroidManifest.xml`:
  ```xml
  android:label="Your App Name"
  ```

---

## PART 3 — SUPABASE SETUP (One-time)

### 3.1 Run SQL files in ORDER
Go to **Supabase → SQL Editor** and run each file:
```
sql6  → Chat system, app_errors, analytics, property_views
sql7  → Subscriptions, payments, app_config, agent_verifications
sql8  → Advertisements, storage buckets, saved_searches, featured
sql9  → Admin RBAC, property_reports, contact_requests, mortgage_inquiries
sql10 → Notifications, price alerts, device_push_tokens
```
**Important:** Run them in this exact order. Each file has `IF NOT EXISTS` guards — safe to re-run.

### 3.2 Set Supabase Realtime on notifications table
Already handled in sql10 extension:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE user_notifications;
```

### 3.3 Configure Row Level Security
All RLS policies are in the SQL files. After running, verify in:
**Supabase → Authentication → Policies**

### 3.4 Set up your backend (Node.js server for Selcom)
```bash
cd real_estate_app_backend
cp .env.example .env
# Fill in SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SELCOM_* keys
npm install
npm start   # test locally first
```

Deploy to Railway (free tier):
1. Go to railway.app → New Project → Deploy from GitHub
2. Connect your repo, set environment variables
3. Copy the Railway URL → paste in `assets/.env` as `SELCOM_BACKEND_URL`

---

## PART 4 — DEPLOY TO PLAY STORE

### 4.1 Create a Keystore (ONE TIME — keep this file SAFE!)
```bash
keytool -genkey -v \
  -keystore ~/upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload \
  -dname "CN=Your Name, O=Your Company, C=TZ"
# Enter a strong password and remember it!
```

### 4.2 Configure signing in Android
Create `android/key.properties`:
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=C:/Users/collins/upload-keystore.jks
```

Update `android/app/build.gradle.kts` to use the keystore:
```kotlin
// Add BEFORE android { ... }
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}
```

### 4.3 Build the App Bundle (AAB)
```bash
flutter clean
flutter pub get
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### 4.4 Create Google Play Console Account
1. Go to **play.google.com/console** → Sign up
2. Pay the one-time $25 developer registration fee
3. Fill in your developer profile

### 4.5 Create your app in Play Console
1. **All apps → Create app**
2. Fill in:
   - App name: "Real Estate App" (or your name)
   - Default language: English (US) or Swahili
   - App or Game: **App**
   - Free or Paid: **Free**
3. Click **Create app**

### 4.6 Fill in Store Listing
Navigate to **Grow → Store presence → Main store listing**:
- **App name**: Your app name (max 30 chars)
- **Short description**: (max 80 chars) e.g. "Buy, sell & rent properties in Tanzania"
- **Full description**: (max 4000 chars) detailed description
- **Screenshots**: minimum 2 phone screenshots (1080×1920px or similar)
  ```bash
  # Take screenshots on a phone or emulator
  # Go to each main screen and capture
  ```
- **Feature graphic**: 1024×500px banner image
- **App icon**: 512×512px PNG

### 4.7 Set up app content ratings
- **Policy → App content → Content rating** → Fill the questionnaire

### 4.8 Set up pricing & distribution
- **Monetize → Pricing & distribution**
- Select countries: Tanzania, Kenya, Uganda, Rwanda (or all)
- Confirm it's not primarily for children

### 4.9 Upload your first build
1. **Release → Testing → Internal testing** (start here — no review needed!)
2. Click **Create new release**
3. Upload `app-release.aab`
4. Add release notes e.g. "Initial release - property search, chat, subscriptions"
5. Click **Save → Review release → Start rollout**

### 4.10 Add testers
1. **Testing → Internal testing → Testers**
2. Add your email and team emails
3. Share the opt-in URL with testers
4. Install on your phone via Play Store (not APK)

### 4.11 Move to Production (when ready)
1. **Release → Production → Create new release**
2. Promote the same build from internal testing
3. Set rollout % to **20%** first (cautious rollout)
4. Submit for **Google review** (usually 1–7 days)
5. Once approved → increase to 100%

---

## PART 5 — DEPLOY AS PROGRESSIVE WEB APP (PWA)

### 5.1 Build the Flutter web app
```bash
flutter clean
flutter build web --release --web-renderer canvaskit --base-href /
# Output: build/web/
```

For better text rendering (smaller size):
```bash
flutter build web --release --web-renderer html --base-href /
```

### 5.2 Choose a hosting provider

**Option A — Netlify (Recommended — Free)**
1. Create account at netlify.com
2. Drag and drop the `build/web/` folder to netlify.com/drop
3. You get a URL like `https://amazing-app-123.netlify.app`
4. **For a custom domain**: Netlify Settings → Domain → Add custom domain

**Option B — Vercel (Free)**
```bash
npm install -g vercel
cd build/web
vercel --prod
```

**Option C — Firebase Hosting (Free tier)**
```bash
npm install -g firebase-tools
firebase login
firebase init hosting
# Public directory: build/web
# Single page app: YES
firebase deploy
```

**Option D — Your own VPS/server (cheapest long-term)**
```bash
# Copy build/web/ to your server
scp -r build/web/* user@yourserver.com:/var/www/html/
# Configure nginx to serve the folder
```

### 5.3 Configure Nginx for PWA (if using own server)
```nginx
server {
    listen 80;
    listen 443 ssl;
    server_name yourdomain.com;

    root /var/www/html;
    index index.html;

    # Compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;

    # Service worker — must not be cached
    location = /service-worker.js {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
    location = /flutter_service_worker.js {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Flutter assets — cache for 1 year
    location /assets/ {
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    # All routes → index.html (Flutter handles routing)
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### 5.4 Enable HTTPS (required for PWA + push notifications)
```bash
# Using Let's Encrypt (free):
apt install certbot python3-certbot-nginx
certbot --nginx -d yourdomain.com
```

### 5.5 Update your domain in web/index.html
Find and replace `https://your-domain.com/` with your real domain:
```html
<meta property="og:url" content="https://yourdomain.com/">
<meta property="twitter:url" content="https://yourdomain.com/">
```

### 5.6 Test your PWA
1. Open Chrome → Navigate to your domain
2. Open DevTools → Application → Manifest → Check all green ✓
3. Application → Service Workers → Should show "Activated and running"
4. Lighthouse tab → Run PWA audit → Should score 90+
5. On Android Chrome → "Add to Home Screen" prompt should appear

### 5.7 Share the PWA link
Users can:
- Open the link in Chrome → tap "Add to Home Screen"
- The app installs like a native app (no Play Store needed!)
- Works on: Android, iPhone (Safari), Windows (Edge/Chrome), Mac, Linux

---

## PART 6 — CONTINUOUS DEPLOYMENT (Automate updates)

### 6.1 Set up GitHub Actions for automatic builds
Create `.github/workflows/deploy.yml`:
```yaml
name: Build & Deploy

on:
  push:
    branches: [main]

jobs:
  deploy-web:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: flutter pub get
      - run: flutter build web --release
      - name: Deploy to Netlify
        uses: nwtgck/actions-netlify@v2
        with:
          publish-dir: './build/web'
          production-branch: main
        env:
          NETLIFY_AUTH_TOKEN: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          NETLIFY_SITE_ID: ${{ secrets.NETLIFY_SITE_ID }}

  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: flutter pub get
      - run: flutter build appbundle --release
      - uses: actions/upload-artifact@v4
        with:
          name: app-release-aab
          path: build/app/outputs/bundle/release/app-release.aab
```

### 6.2 After every update, increment the build number
```yaml
# pubspec.yaml
version: 1.0.1+2   # new feature
version: 1.0.2+3   # another update
```

---

## PART 7 — POST-LAUNCH CHECKLIST

### Before going live:
- [ ] Change `selcom_env` in `app_config` table from `sandbox` → `live`
- [ ] Add real Selcom live credentials to backend `.env`
- [ ] Replace all `your-domain.com` placeholders in `index.html`
- [ ] Set a privacy policy URL (required by Play Store)
- [ ] Create a simple privacy policy page (use Netlify or GitHub Pages)
- [ ] Test payment flow end-to-end with real Selcom test card
- [ ] Test push notifications on a real Android device
- [ ] Run `flutter analyze` — fix any warnings
- [ ] Run `flutter test` — all tests should pass

### Privacy policy (required for Play Store)
Minimum content:
- What data you collect (email, location, photos)
- How you use it (property listings, messaging)
- Supabase as data processor
- Contact email for data requests
Host it at: `https://yourdomain.com/privacy`

---

## QUICK REFERENCE

| Task | Command |
|------|---------|
| Run tests | `flutter test` |
| Analyze code | `flutter analyze` |
| Build Android bundle | `flutter build appbundle --release` |
| Build web (PWA) | `flutter build web --release` |
| Run on device | `flutter run --release` |
| Update packages | `flutter pub upgrade` |
| Clean build | `flutter clean && flutter pub get` |

---
*Generated for Real Estate App — Play Store + PWA Deployment*
