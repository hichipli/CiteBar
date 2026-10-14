<div align="center">

[English](../README.md) · [简体中文](README.zh-CN.md) · [繁體中文](README.zh-TW.md) · **日本語** · [한국어](README.ko.md) · [Español](README.es.md) · [Português](README.pt-BR.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [Русский](README.ru.md)

<img src="../Assets.xcassets/AppIcon.appiconset/256.png" alt="CiteBar ロゴ" width="112" height="112">

# CiteBar

**Google Scholar の再読み込みは、もう卒業しましょう。**<br>
つい引用数を確かめてしまう、すべての人へ。

[ダウンロード](https://github.com/hichipli/CiteBar/releases/latest) · [公式サイト](https://www.citebar.org/) · `brew install --cask hichipli/tap/citebar`

  [![Latest Release](https://img.shields.io/github/v/release/hichipli/CiteBar?style=flat-square)](https://github.com/hichipli/CiteBar/releases)
  [![macOS](https://img.shields.io/badge/macOS-13.0+-blue?style=flat-square)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-6.0-orange?style=flat-square)](https://swift.org)
  [![License](https://img.shields.io/github/license/hichipli/CiteBar?style=flat-square)](../LICENSE)
  [![Downloads](https://img.shields.io/github/downloads/hichipli/CiteBar/total?style=flat-square)](https://github.com/hichipli/CiteBar/releases)

<img src="../website/assets/demo.gif" alt="メニューバーのパネルから Citation Record の画面へ。タイムマシンを被引用数が 1,000 に達した日までさかのぼり、Gazette、Certificate、Night の各テーマを試しているところ" width="420">

</div>

---

## なぜ CiteBar なのか

20 分おきに Google Scholar のプロフィールを再読み込みしても、研究は進みません。CiteBar は、つい何度も開いてしまうブラウザのタブを、メニューバーに静かに寄り添う相棒に変えます。チェックは 1 日 1 回。どの論文が新たに引用されたかを知らせ、それ以外のときは邪魔をしません。

論文のインパクトを追いかけている研究者、初めての被引用を喜ぶ博士課程の学生、研究室全体の動きを見守る PI、そして「今、h-index 上がった？」と一度でも気になったことのあるすべての人にぴったりです。

## クイックスタート

**すぐに CiteBar を使いたい方へ。** 技術的な説明は飛ばして、1 分ほどで使い始められます。

1. **最新リリースをダウンロード**
   - [GitHub Releases](https://github.com/hichipli/CiteBar/releases/latest) を開きます。
   - `CiteBar-x.x.x-universal-[日付].dmg` ファイルをダウンロードします。
   - このユニバーサル版 DMG は、Apple シリコン搭載の Mac と Intel 搭載の Mac のどちらでも動作します。
   - Homebrew をお使いなら、`brew install --cask hichipli/tap/citebar` でステップ 1 と 2 をまとめて済ませられます。

2. **CiteBar をインストール**
   - DMG を開きます。
   - `CiteBar.app` を `Applications`（アプリケーション）フォルダにドラッグします。
   - `Applications` から CiteBar を起動します。

3. **プロフィールを追加**
   - 初回起動時には Add Profiles が開きます。ご自身の Google Scholar プロフィールのリンクを貼り付けてください。
   - 研究室のメンバーや共著者もフォローしたい場合は、全員分のリンクを 1 行に 1 つずつまとめて貼り付け、グループに入れておけます。
   - 更新は 1 日 1 回がデフォルトです。Google Scholar 自体の更新も 1〜2 日おきなので、これで常に最新の状態を保てます。

プロフィールのリンクをそのまま貼り付けても、ID だけを貼り付けてもかまいません。ID は URL の `user` の値です。

```text
https://scholar.google.com/citations?user=YOUR_ID_HERE
```

現在のリリースは Apple Developer ID で署名され、Apple の公証（notarization）を受けています。それでも、インターネットからダウンロードしたアプリを初めて開くときには、macOS が通常の確認ダイアログを表示することがあります。

`1.3.x` または `1.4.1` からアップグレードする場合は、一度だけ最新の DMG を手動でインストールしてください。それ以降は、アプリ内の自動アップデートが通常どおり機能します。

インストールでお困りの場合は、[インストールガイド](../DISTRIBUTION.md)（英語）をご覧ください。

## 主な機能

<img src="../website/assets/panel.png" alt="CiteBar のパネル：被引用数 1,284 のプロフィール、年ごとの被引用数、新たに引用された論文、h-index を 14 に押し上げる 2 本の論文、ウォッチ中の 2 本の論文、そして合計被引用数を表示する研究室のグループ" width="360">

**数字に、文脈を**
- 被引用数はメニューバーに常に表示され、クリックするとパネルが開きます
- 年ごとの被引用数、今年の被引用数、直近 30 日の増加数、h-index、i10-index
- どの論文が新たに引用されたかがわかり、クリックすれば誰が引用したかまでたどれます
- 次の h-index が見えてきたら、どの論文があと何回引用されればよいかを正確に表示します
- 特定の論文をウォッチ：Papers window でスターを付けるとパネルに常に表示され、通知でもその論文の新しい引用が真っ先に表示されます
- 列ラベルとホバー時のヒントで、すべての数字の意味がひと目でわかります

**研究室や共同研究者のためのグループ**
- プロフィールを研究室、共著者、同期などのグループにまとめ、合計被引用数と直近 30 日の増加数を表示
- Scholar のリンクをまとめて一度に貼り付け可能
- グループのリンクをコピーして研究室のメンバーに共有すれば、各自の CiteBar に貼り付けるだけで同じグループを再現できます

**開きたくなる通知**
- 通知には、引用が増えた論文の名前が表示されます
- 被引用数 100 や 1,000 といった節目や、h-index の上昇は個別にお知らせします
- 「変化なし」のような無駄な通知は送りません

**シェアしたくなる引用記録**
- 4 種類のカードスタイル：Record、Night、Gazette（あなたの数字から見出しを組み立てる新聞の一面風）、Certificate
- 表示する内容を選べます：年ごとの被引用数、h-index、被引用数の多い論文または特定の 1 本、7〜365 日間の増加数、ひとことメモ
- 共有（AirDrop、メッセージ、メール）、コピー、保存をワンクリックで。パネルからでも、Settings にある各プロフィールの ⋯ メニューからでも操作できます

<img src="../website/assets/card-record.png" alt="Record カード" width="180"> <img src="../website/assets/card-night.png" alt="Night カード" width="180"> <img src="../website/assets/card-gazette.png" alt="Gazette カード" width="180"> <img src="../website/assets/card-certificate.png" alt="Certificate カード" width="180">

**あなたの記録をたどるタイムマシン**
- タイムラインをドラッグして好きな日を選び、その日のカードを作成できます
- 被引用数の節目や h-index の上昇には印が付くので、見逃した瞬間もあとからシェアできます
- 初日から使えます：CiteBar をインストールする前の節目は Google Scholar の年ごとの被引用数から日付を推定して ~ を付け、インストール以降は毎日の数字を正確に記録します

**控えめで、確実に**
- リクエストはプロフィールごとに 1 回、2 秒の間隔を空けて送信
- ネットワークの一時的な不調は自動で再試行。Google Scholar のレート制限にかかった場合は間隔を段階的に延ばし（15 分から最大 4 時間）、自動で再開します
- Refresh Now でいつでも手動更新が可能
- Sparkle による自動アップデート

**最初からプライバシー重視**
- すべてのデータはお使いの Mac の中に保存
- テレメトリなし
- CiteBar のサーバーもアカウントもなし

**データは自由に持ち運べる**
- Settings › Data で、データの保存場所（`~/Library/Application Support/CiteBar/`）と、引用履歴・論文リスト・論文履歴それぞれの使用容量を確認できます
- 引用履歴は無期限に保存する（デフォルト）か、5 年、2 年、1 年から選べます
- オプションの論文履歴を有効にすると、各論文の被引用数が変わるたびに記録されるため、タイムマシンで過去の日を表示したときも論文ごとの数字が表示されます
- すべて（プロフィール、グループ、設定、全履歴）を 1 つのファイルに書き出し、新しい Mac で読み込めます。読み込みはデータを追加するだけで、削除することはありません
- オプションで、更新のたびに iCloud Drive や、Google Drive・Dropbox など任意のフォルダへ自動バックアップできます

**macOS ネイティブの使い心地**
- メニューバーに軽やかに常駐し、ライトモードとダークモードに対応
- Profiles、General、Data、About の各タブを備えたネイティブの設定画面
- ログイン時の自動起動に対応
- Apple シリコンと Intel の両方に対応

**起動しっぱなしでも気にならない軽さ**
- アイドル時の CPU 使用率はほぼゼロ
- ネットワーク通信は、設定した間隔での最小限のみ
- 実装の詳細は [技術ノート](../TECHNICAL.md)（英語）をご覧ください

## プライバシー

CiteBar が読み込むのは、一般公開されている Google Scholar のプロフィールページだけです。設定と引用履歴はお使いの Mac の `~/Library/Application Support/CiteBar/` に保存されます。

アプリは控えめな更新間隔、リクエスト間の待機時間、エラー後のバックオフによって、節度をもって被引用数を確認します。

## ヘルプとプロジェクトのドキュメント

- インストールや macOS のセキュリティダイアログについて：[インストールガイド](../DISTRIBUTION.md)
- ソースからのビルド：[セットアップガイド](../SETUP.md)
- バグ報告や機能リクエスト：[GitHub Issues](https://github.com/hichipli/CiteBar/issues)
- プロジェクトの変更点：[変更履歴](../CHANGELOG.md)

上記のドキュメントはいずれも英語ですが、issue は日本語で書いていただいてもかまいません。

アイデアや、まだ荒削りな機能リクエスト、CiteBar がうまく対応できていないワークフローがあれば、ぜひ issue を立ててください。完成された提案やプルリクエストを用意する必要はありません。実際の研究の現場から寄せられる具体的なフィードバックは、それだけで大きな価値があります。

## 開発者・コントリビューターの方へ

ソースからビルドしたい、コードで貢献したい、あるいは CiteBar の内部の仕組みを知りたいという方はこちらをどうぞ。

```bash
git clone https://github.com/hichipli/CiteBar.git
cd CiteBar
make build
make run
```

参考になるプロジェクトドキュメント（英語）：

- [コントリビューションガイド](../CONTRIBUTING.md)
- [技術ノート](../TECHNICAL.md)
- [リリースガイド](../RELEASING.md)
- [バージョン管理](../VERSION_MANAGEMENT.md)

## ライセンス

CiteBar は [MIT License](../LICENSE) のもとで公開されています。

## コミュニティ

CiteBar をより良くするために力を貸してくださっている皆さんに感謝します。

<div>
  <a href="https://github.com/CassWang1"><img src="https://github.com/CassWang1.png?size=48" width="48" alt="CassWang1" /></a>
  <a href="https://github.com/lukestein"><img src="https://github.com/lukestein.png?size=48" width="48" alt="lukestein" /></a>
  <a href="https://github.com/DABH"><img src="https://github.com/DABH.png?size=48" width="48" alt="DABH" /></a>
  <a href="https://github.com/yizirui"><img src="https://github.com/yizirui.png?size=48" width="48" alt="yizirui" /></a>
</div>

---

<div align="center">

**学術コミュニティのために、心を込めて開発しています**

[最新リリースをダウンロード](https://github.com/hichipli/CiteBar/releases/latest) | [問題を報告](https://github.com/hichipli/CiteBar/issues) | [コントリビュートする](../CONTRIBUTING.md)

</div>
