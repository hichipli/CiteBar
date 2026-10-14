<div align="center">

[English](../README.md) · [简体中文](README.zh-CN.md) · **繁體中文** · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Português](README.pt-BR.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Русский](README.ru.md)

<img src="../Assets.xcassets/AppIcon.appiconset/256.png" alt="CiteBar 標誌" width="112" height="112">

# CiteBar

**別再一直重新整理 Google Scholar 了。**<br>
獻給每一位總忍不住去看引用次數的人。

[下載](https://github.com/hichipli/CiteBar/releases/latest) · [官方網站](https://www.citebar.org/) · `brew install --cask hichipli/tap/citebar`

  [![Latest Release](https://img.shields.io/github/v/release/hichipli/CiteBar?style=flat-square)](https://github.com/hichipli/CiteBar/releases)
  [![macOS](https://img.shields.io/badge/macOS-13.0+-blue?style=flat-square)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square)](https://swift.org)
  [![License](https://img.shields.io/github/license/hichipli/CiteBar?style=flat-square)](../LICENSE)
  [![Downloads](https://img.shields.io/github/downloads/hichipli/CiteBar/total?style=flat-square)](https://github.com/hichipli/CiteBar/releases)

<img src="../website/assets/demo.gif" alt="從選單列面板到 Citation Record 分享頁：把時光機拖回引用突破 1,000 次的那一天，再依序切換 Gazette、Certificate 和 Night 主題" width="420">

</div>

---

## 為什麼要用 CiteBar？

每二十分鐘就重新整理一次 Google Scholar 個人頁面，並不會讓研究進展得更快。CiteBar 把那個讓人一再重新整理的瀏覽器分頁，變成選單列裡一個安靜的小幫手：每天檢查一次，告訴你剛剛是哪篇論文被引用了，其餘時間都不打擾你。

適合在意論文影響力的研究人員、正在慶祝第一次被引用的博士生、想隨時掌握整個實驗室狀況的指導教授，以及每一個曾經想過「我的 h-index 是不是剛剛漲了？」的人。

## 快速上手

**只想直接使用？** 跳過技術細節，大約一分鐘就能開始用。

1. **下載最新版本**
   - 前往 [GitHub Releases](https://github.com/hichipli/CiteBar/releases/latest)。
   - 下載 `CiteBar-x.x.x-universal-[日期].dmg` 檔案。
   - 這個通用版 DMG 同時支援搭載 Apple 晶片和 Intel 處理器的 Mac。
   - 習慣用 Homebrew？執行 `brew install --cask hichipli/tap/citebar`，第 1、2 步就會自動完成。

2. **安裝 CiteBar**
   - 打開 DMG。
   - 把 `CiteBar.app` 拖進 `Applications`（應用程式）資料夾。
   - 從 `Applications` 啟動 CiteBar。

3. **加入你的個人頁面**
   - 第一次啟動時，CiteBar 會打開 Add Profiles 視窗。貼上你的 Google Scholar 個人頁面連結即可。
   - 想追蹤整個實驗室或共同作者？一次貼上所有人的連結，每行一個，再把他們放進同一個群組。
   - 預設每天重新整理一次。Google Scholar 本身每一兩天才更新一次，所以每天更新就足以保持最新。

你可以貼上完整的個人頁面連結，也可以只貼 ID，也就是網址中 `user` 後面的那一串：

```text
https://scholar.google.com/citations?user=YOUR_ID_HERE
```

目前的版本都以 Apple Developer ID 簽署，並通過 Apple 公證（notarize）。對於從網路下載的 App，macOS 第一次打開時仍可能跳出一次一般性的確認視窗。

如果你是從 `1.3.x` 或 `1.4.1` 升級，請手動安裝一次最新的 DMG。之後 App 內的自動更新就能正常運作。

安裝遇到問題？請參閱[安裝指南](../DISTRIBUTION.md)（英文）。

## 主要功能

<img src="../website/assets/panel.png" alt="CiteBar 面板：一位引用次數 1,284 次的學者、每年引用次數、一篇剛被引用的論文、能把 h-index 推上 14 的兩篇論文、兩篇追蹤中的論文，以及一個顯示合計引用次數的實驗室群組" width="360">

**不只是一個數字**
- 引用次數常駐在選單列，點一下就展開面板
- 每年引用次數、今年的引用次數、近 30 天成長、h-index 和 i10-index
- 看到剛被引用的是哪篇論文，點一下就能查看是誰引用了它
- h-index 快要往上跳時，明確告訴你是哪幾篇論文、各自還差幾次引用
- 追蹤特定論文：在 Papers 視窗中為論文加上星號，它們就會一直顯示在面板上，有新引用時也會在通知中排在最前面
- 每一欄都有標籤，滑鼠移過去還有說明，每個數字都一看就懂

**為實驗室和合作夥伴準備的群組**
- 把個人頁面分成實驗室、共同作者或同屆同學等群組，顯示合計引用次數和近 30 天成長
- 一次貼上一整串 Scholar 連結
- 拷貝整個群組的連結傳給實驗室夥伴，他們貼進自己的 CiteBar 就能看到同樣的群組

**值得點開的通知**
- 通知會寫明是哪幾篇論文多了引用
- 引用次數達到 100、1,000 這類里程碑，或 h-index 上升時，會另外通知你
- 不會有「沒有變化」這種干擾訊息

**值得分享的引用紀錄**
- 四種卡片風格：Record、Night、Gazette（報紙頭版風格，標題依你的數據自動產生）和 Certificate（證書）
- 自由選擇要顯示的內容：每年引用次數、h-index、被引用最多的論文或單一篇論文、7 到 365 天的成長，以及一段附註
- 一鍵分享（AirDrop、訊息、郵件）、拷貝或儲存；可以從面板打開，也可以從設定中任一個人的 ⋯ 選單打開

<img src="../website/assets/card-record.png" alt="Record 卡片" width="180"> <img src="../website/assets/card-night.png" alt="Night 卡片" width="180"> <img src="../website/assets/card-gazette.png" alt="Gazette 卡片" width="180"> <img src="../website/assets/card-certificate.png" alt="Certificate 卡片" width="180">

**屬於你的引用時光機**
- 沿著時間軸拖到任何一天，產生那一天的卡片
- 引用里程碑和 h-index 上升都會標示出來，錯過的高光時刻也能補發
- 第一天就能用：安裝 CiteBar 之前的里程碑，會依據 Google Scholar 的每年引用次數推估日期並標上 ~；從安裝那天起，每一天都精確記錄

**有分寸又可靠**
- 每個個人頁面只發出一次請求，請求之間間隔兩秒
- 網路不穩時會自動重試；遇到 Google Scholar 限制請求頻率時會逐步放慢（從 15 分鐘到 4 小時），之後自動恢復
- 隨時都能按 Refresh Now 手動更新
- 透過 Sparkle 自動更新

**預設就重視隱私**
- 所有資料都留在你的 Mac 上
- 沒有任何遙測
- 沒有 CiteBar 伺服器，也不需要註冊帳號

**資料隨身帶著走**
- Settings › Data 會顯示資料存放的位置（`~/Library/Application Support/CiteBar/`），以及各部分分別佔用多少空間：引用歷史、論文列表和論文歷史
- 引用歷史預設永久保留，也可以只保留 5 年、2 年或 1 年
- 可選擇開啟論文歷史：每篇論文的引用次數一有變化就記錄下來，時光機中過去的日子也能顯示當時的論文
- 把所有內容（個人頁面、群組、設定和完整歷史）匯出成一個檔案，再到新的 Mac 上匯入；匯入只會新增，絕不會刪除任何資料
- 可選擇在每次更新後自動備份到 iCloud 雲碟，或你指定的任何資料夾，例如 Google Drive 或 Dropbox

**道地的 macOS 體驗**
- 輕巧地待在選單列，支援淺色和深色模式
- 原生設定視窗，包含 Profiles、General、Data 和 About 四個分頁
- 支援登入時自動啟動
- 支援 Apple 晶片和 Intel 處理器

**輕巧到可以一直開著**
- 閒置時 CPU 使用率幾乎為零
- 只在你設定的時間間隔進行少量網路連線
- 更多實作細節請見[技術說明](../TECHNICAL.md)（英文）

## 隱私

CiteBar 只會讀取公開的 Google Scholar 個人頁面。你的設定和引用歷史都儲存在你的 Mac 上，位於 `~/Library/Application Support/CiteBar/`。

App 採用保守的更新間隔，請求之間保留間隔，出錯後也會主動退避，以負責任的方式查詢引用次數。

## 說明與專案文件

- 安裝問題或 macOS 安全性提示：[安裝指南](../DISTRIBUTION.md)
- 從原始碼建置：[建置指南](../SETUP.md)
- 錯誤回報與功能建議：[GitHub Issues](https://github.com/hichipli/CiteBar/issues)
- 版本變更：[更新紀錄](../CHANGELOG.md)

以上文件皆為英文。

有想法、還不成熟的功能建議，或是 CiteBar 還沒辦法好好支援的工作流程？歡迎開一個 issue，用中文寫也沒問題。不需要準備完整的提案或 pull request，來自真實研究情境的實際回饋本身就很有價值。

## 開發者與貢獻者

想從原始碼建置、貢獻程式碼，或了解 CiteBar 的內部運作？

```bash
git clone https://github.com/hichipli/CiteBar.git
cd CiteBar
make build
make run
```

相關專案文件（英文）：

- [貢獻指南](../CONTRIBUTING.md)
- [技術說明](../TECHNICAL.md)
- [發布指南](../RELEASING.md)
- [版本管理](../VERSION_MANAGEMENT.md)

## 授權條款

CiteBar 以 [MIT License](../LICENSE) 授權開源。

## 社群

感謝每一位讓 CiteBar 變得更好的朋友。

<div>
  <a href="https://github.com/CassWang1"><img src="https://github.com/CassWang1.png?size=48" width="48" alt="CassWang1" /></a>
  <a href="https://github.com/lukestein"><img src="https://github.com/lukestein.png?size=48" width="48" alt="lukestein" /></a>
  <a href="https://github.com/DABH"><img src="https://github.com/DABH.png?size=48" width="48" alt="DABH" /></a>
  <a href="https://github.com/yizirui"><img src="https://github.com/yizirui.png?size=48" width="48" alt="yizirui" /></a>
</div>

---

<div align="center">

**用心為學術圈打造**

[下載最新版本](https://github.com/hichipli/CiteBar/releases/latest) | [回報問題](https://github.com/hichipli/CiteBar/issues) | [參與貢獻](../CONTRIBUTING.md)

</div>
