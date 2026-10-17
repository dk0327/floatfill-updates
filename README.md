# 懸浮填表（FloatFill）更新來源

這個 repo 是「懸浮填表」Android App 的**線上更新來源**，請保持**公開**（App 不帶任何 token，直接讀公開網址）。

## 檔案
| 路徑 | 用途 |
|---|---|
| `update.json` | 最新版資訊：versionCode、versionName、minSdk、apkUrl、sha256、size、notes |
| `apk/FloatFill-<版本>-arm64-release.apk` | arm64 精簡版 APK（約 16 MB，一般 Android 手機都用這個） |
| `publish.sh` | 發布新版的輔助腳本 |

## 更新怎麼運作
1. App（0.2.0 起）開啟時（可在 設定 → 線上更新 關閉自動檢查）或按「檢查更新」，讀取
   `https://raw.githubusercontent.com/dk0327/floatfill-updates/main/update.json`。
2. `versionCode` 比手機上的大才提示，並顯示 `notes`。
3. 下載 `apkUrl`（只接受 GitHub 的 HTTPS 網址）到 App 快取，顯示進度。
4. 依序核對：檔案大小＝`size`、**SHA-256＝`sha256`**、套件名稱、版本號，以及 **APK 簽章憑證必須與手機上已安裝版本相同**。任何一項不符就刪檔、拒絕安裝。
5. 交給 Android 的 PackageInstaller；系統一定會跳出確認畫面，由你按「更新」。第一次需要允許「安裝不明應用程式」（App 會帶你到該設定頁）。

> 注意：手機上若還是 0.1.0（沒有更新功能），要先手動安裝一次 0.2.0，之後才能線上更新。
> raw.githubusercontent.com 有約 5 分鐘快取，剛推送的新版可能要稍等才看得到。

## 發布新版
在建置環境（/workspace/android-float-fill）：
```bash
cd github-updates
./publish.sh 0.2.1 "這次更新的繁中說明"          # 只建 arm64
./publish.sh 0.2.1 "說明" --universal           # 另外產生完整多架構版到 dist/
```
腳本會：versionCode +1、改 versionName、跑單元測試、建置、確認簽章憑證仍是
`f558927d23a25d07abfee924126054ee440addaf752f82c6057177e4d0e8726f`、把 APK 放進 `apk/`（刪掉舊的）、計算 SHA-256 與大小、重寫 `update.json`。
然後推送：**先推 APK，再推 update.json**（避免手機讀到新 json 卻抓不到檔）。

一定要用同一把測試金鑰（`app-project/keystore/floatfill-test.jks`）簽署，換金鑰的 APK 會被 App 拒絕，系統也無法覆蓋安裝。

## 完整多架構版（約 44 MB）
可放到 GitHub **Releases**（例如 tag `v0.2.0` 的附件），再把 `update.json` 的 `apkUrl` 改成
`https://github.com/dk0327/floatfill-updates/releases/download/v0.2.0/FloatFill-0.2.0-release.apk`，`sha256`／`size` 改成該檔的值。App 允許 github.com 及其下載轉址網域。

## 安全
- 只用 HTTPS、只接受 GitHub 網域；sha256 或簽章不符一律拒絕（fail closed）。
- 不做靜默安裝；不收集或上傳任何使用者資料。
- 這是測試金鑰簽署的原型，不可上架。
