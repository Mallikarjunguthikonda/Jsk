#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PROJECT="$HOME/love-app"
ANDROID_JAR="$HOME/android-sdk/platforms/android-34/android.jar"
OUT="$PROJECT/build"
PKG="com/loveapp"
PKG_DOT="com.loveapp"

rm -rf "$OUT"
mkdir -p "$OUT"/{classes,gen,apk}

echo "=== Step 1: Generate R.java ==="
cd "$PROJECT"
aapt package -f -m \
    -J "$OUT/gen" \
    -M AndroidManifest.xml \
    -S res \
    -I "$ANDROID_JAR"

echo "=== Step 2: Compile Java sources (release 11) ==="
javac -source 11 -target 11 \
    -cp "$ANDROID_JAR" \
    -d "$OUT/classes" \
    "$OUT/gen/$PKG/R.java" \
    src/$PKG/MainActivity.java

echo "=== Step 3: Convert to DEX ==="
cd "$OUT/classes"
d8 --lib "$ANDROID_JAR" \
    --output "." \
    $PKG/*.class
ls -la classes.dex

echo "=== Step 4: Package APK with resources ==="
cd "$PROJECT"
aapt package -f \
    -M AndroidManifest.xml \
    -S res \
    -A assets \
    -I "$ANDROID_JAR" \
    -F "$OUT/love-unsigned.apk"

echo "=== Step 5: Add classes.dex to APK ==="
aapt add -f "$OUT/love-unsigned.apk" "$OUT/classes/classes.dex"

echo "=== Step 6: Generate debug keystore ==="
KEYSTORE="$OUT/debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
    keytool -genkey -v -keystore "$KEYSTORE" \
        -alias debug -keyalg RSA -keysize 2048 \
        -validity 10000 \
        -storepass android -keypass android \
        -dname "CN=LoveApp, OU=Dev, O=LoveApp, L=Unknown, ST=Unknown, C=US"
fi

echo "=== Step 7: Sign APK ==="
apksigner sign --ks "$KEYSTORE" \
    --ks-pass pass:android \
    --key-pass pass:android \
    "$OUT/love-unsigned.apk"

mv "$OUT/love-unsigned.apk" "$OUT/love.apk"

echo ""
echo "=== SUCCESS ==="
echo "APK created at: $OUT/love.apk"
ls -lh "$OUT/love.apk"

echo ""
echo "=== To install directly on device ==="
echo "  cp $OUT/love.apk /sdcard/Download/"
echo "Then open the file with a file manager to install."
