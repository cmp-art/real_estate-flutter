@echo off
REM ============================================================
REM  Patamjengo — Release Build Script
REM  Builds a signed App Bundle (AAB) for Google Play Store
REM
REM  USAGE:
REM    build_release.bat
REM
REM  OUTPUT:
REM    build\app\outputs\bundle\release\app-release.aab
REM ============================================================

echo.
echo ============================================================
echo  Patamjengo Release Build
echo ============================================================
echo.

REM ── 1. Clean previous build ──────────────────────────────────
echo [1/4] Cleaning previous build...
call flutter clean
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: flutter clean failed.
    exit /b 1
)

REM ── 2. Get dependencies ──────────────────────────────────────
echo.
echo [2/4] Getting dependencies...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: flutter pub get failed.
    exit /b 1
)

REM ── 3. Build App Bundle ──────────────────────────────────────
echo.
echo [3/4] Building release App Bundle (AAB)...
echo       (This may take 5-10 minutes on first build)
echo.

call flutter build appbundle --release ^
  --dart-define=SUPABASE_URL=https://qeddjlmexurmeiuslgqn.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_0xoE2u_TeJIrKkO4KMZYbw_-1iuEaxy ^
  --dart-define=GOOGLE_WEB_CLIENT_ID=445099974533-oel8r3kqgn6pa4mg5u983rk3e9p1fpir.apps.googleusercontent.com ^
  --dart-define=APP_ENVIRONMENT=production

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Build failed. Check the output above for details.
    exit /b 1
)

REM ── 4. Verify signing ────────────────────────────────────────
echo.
echo [4/4] Verifying release signing...
keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab 2>nul | findstr /I "owner\|issuer\|alias\|SHA"

echo.
echo ============================================================
echo  BUILD SUCCESSFUL
echo  Output: build\app\outputs\bundle\release\app-release.aab
echo ============================================================
echo.
echo  Next steps:
echo    1. Test the AAB on a physical device using bundletool
echo    2. Upload to Play Console: Internal Testing track first
echo    3. Promote to Production after testing
echo.
pause
