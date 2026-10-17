#!/usr/bin/env bash
# 發布新版：調高 versionCode、重建 arm64（必要時加完整版）、計算 SHA-256、重寫 update.json。
# 用法：./publish.sh <versionName> "<繁中更新說明>" [--universal]
# 例：  ./publish.sh 0.2.1 "修正懸浮窗位置記憶" 
# 本腳本不會推送；完成後依畫面提示 git add / commit / push。
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${FLOATFILL_ROOT:-/workspace/android-float-fill}"
PROJ="$ROOT/app-project"; GRADLE_FILE="$PROJ/app/build.gradle.kts"
REPO="${FLOATFILL_REPO:-dk0327/floatfill-updates}"; BRANCH="${FLOATFILL_BRANCH:-main}"
EXPECTED_CERT="f558927d23a25d07abfee924126054ee440addaf752f82c6057177e4d0e8726f"
NAME="${1:?請給 versionName，例如 0.2.1}"; NOTES="${2:?請給更新說明}"; UNIVERSAL="${3:-}"

source "$ROOT/env.sh"
OLD_CODE=$(grep -oE 'versionCode = [0-9]+' "$GRADLE_FILE" | grep -oE '[0-9]+')
CODE=$((OLD_CODE + 1))
sed -i -E "s/versionCode = [0-9]+; versionName = \"[^\"]*\"/versionCode = ${CODE}; versionName = \"${NAME}\"/" "$GRADLE_FILE"
echo "versionCode ${OLD_CODE} → ${CODE}，versionName ${NAME}"

cd "$PROJ"
./gradlew --no-daemon testDebugUnitTest
mkdir -p "$ROOT/dist"
if [[ "$UNIVERSAL" == "--universal" ]]; then
  ./gradlew --no-daemon assembleRelease
  cp app/build/outputs/apk/release/app-release.apk "$ROOT/dist/FloatFill-${NAME}-release.apk"
fi
./gradlew --no-daemon assembleRelease -PabiArm64Only=true
APK_NAME="FloatFill-${NAME}-arm64-release.apk"
cp app/build/outputs/apk/release/app-release.apk "$ROOT/dist/$APK_NAME"

# 簽章必須仍是同一把測試金鑰，否則手機上的舊版無法更新
CERT=$(apksigner verify --print-certs "$ROOT/dist/$APK_NAME" | awk -F': ' '/Signer #1 certificate SHA-256 digest/{print $2}')
[[ "$CERT" == "$EXPECTED_CERT" ]] || { echo "簽章憑證不符：$CERT" >&2; exit 1; }

rm -f "$HERE"/apk/*.apk
cp "$ROOT/dist/$APK_NAME" "$HERE/apk/"
SHA=$(sha256sum "$HERE/apk/$APK_NAME" | cut -d' ' -f1); SIZE=$(stat -c %s "$HERE/apk/$APK_NAME")
(( SIZE < 95*1024*1024 )) || { echo "APK 超過 GitHub 單檔 100MB 限制，請改放 Releases" >&2; exit 1; }
URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/apk/${APK_NAME}"
python3 - "$HERE/update.json" "$CODE" "$NAME" "$URL" "$SHA" "$SIZE" "$NOTES" <<'PY'
import json, sys
p, code, name, url, sha, size, notes = sys.argv[1:]
json.dump({"versionCode": int(code), "versionName": name, "minSdk": 26, "apkUrl": url,
           "sha256": sha, "size": int(size), "notes": notes}, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
open(p, "a").write("\n")
PY
echo; cat "$HERE/update.json"
echo; echo "完成。接著推送（APK 要先到、update.json 最後改）："
echo "  cd $HERE && git add apk/$APK_NAME && git commit -m 'apk ${NAME}' && git add -A && git commit -m 'release ${NAME}' && git push"
