# 古文単語・文法アプリ 設計書

大学受験（共通テスト〜私大標準レベル）向けの古文単語＋古典文法の学習アプリ。
`C:\System_Dev\eitango_app_01`（英検2級 英単語特訓）を参考元とし、**同じ技術構成・同じ実証済みロジックを流用しながら、コンテンツ構造を大幅に簡素化する**。

本書は実装モデルへの指示書を兼ねる。実装時は参考元リポジトリを常に手元に置き、§10 の移植対応表に従ってファイル単位で流用・改変・新規作成すること。

## 決定済みの方針（ユーザー確認済み）

- タブは **ホーム / 単語帳 / クイズ / 聞き流し** の4つ
- 文法は**単語帳タブ内のセグメント切替**（単語⇄文法）で扱う。クイズも「単語クイズ／文法クイズ」を選べる
- 課金は参考元と同方式: **14日試用 → 買い切り1商品で全解放**。広告・サブスクなし
- 単語は**300語台**。階層（Tier）・分野（Domain）・頻出度（Category）は持たない
- タイピング機能・ユーザーによる単語追加機能は作らない
- 完全オフライン（参考元と同じ。サーバー通信・アカウントなし、TTSはOS標準）

---

## 1. 参考元との差分一覧

| 項目 | 英単語アプリ | 本アプリ |
| --- | --- | --- |
| タブ | ホーム/単語帳/クイズ/タイピング/聞き流し | ホーム/単語帳/クイズ/聞き流し |
| コンテンツ | 単語 3,955語（3階層×8分野×頻出度） | 単語 314語 + 文法 80項目 + 文法問題 125問。属性は品詞のみ |
| 単語帳 | 単語のみ。フィルタ多数 | セグメントで単語⇄文法切替。フィルタは習熟度と検索のみ |
| クイズ | 4択（意味を選ぶ、自動生成） | 単語クイズ（自動生成4択）+ 文法クイズ（同梱問題バンク） |
| タイピング | 寿司打風タイムアタック | **作らない** |
| 聞き流し | 単語→意味→例文をTTS再生 | 同じ（単語のみ。文法は対象外） |
| SRS | Leitner固定テーブル | **そのまま流用** |
| 学習履歴 | 日次グラフ+連続日数 | **そのまま流用** |
| 課金 | 試用14日→買い切りでTier3解放 | 試用14日→買い切りで全出題解放（無料範囲は isFree フラグ） |
| ユーザー単語追加 | あり（UserWord/WordEditor） | **作らない** |
| シリーズ展開（Edition機構） | 設計あり | **考慮しない**（単体アプリ） |

---

## 2. 技術構成（参考元と同一）

- **iOS 17+ / SwiftUI / SwiftData / Swift 5 (strict concurrency: complete)**
- `.xcodeproj` はコミットせず **XcodeGen**（`project.yml`）で生成
- Mac実機なし運用: ビルド確認・UIテストスクリーンショット・TestFlight配信はすべて **GitHub Actions** の macOS ランナー（参考元の `.github/workflows/` 一式を流用）
- TTS は `AVSpeechSynthesizer`（音声ファイル同梱なし）
- 課金は StoreKit 2、非消耗型1商品

### 参考元から引き継ぐ実装上の教訓（必読）

参考元の `project.yml` / `README.md` のコメントに実運用で踏んだ落とし穴が記録されている。同じ構成を取ること。

1. **`INFOPLIST_FILE` を直接指定**し、XcodeGen の `info:` 生成は使わない（手書き Info.plist が上書きされ、`UIBackgroundModes` が欠落して聞き流しのバックグラウンド再生が壊れた実績がある）
2. **`PRODUCT_NAME` は ASCII 固定**（日本語名はビルドパスに波及して TEST_HOST 解決が壊れる）。表示名は `CFBundleDisplayName`
3. シードのバージョン記録は `context.save()` **成功後**に行う（逆順だと失敗時に復旧不能）
4. `WordMaster` 相当と進捗は `@Relationship` を張らず **String ID で疎結合**（マスター総入れ替え時に履歴を守る）
5. 永続ストアが開けない場合はインメモリにフォールバックして起動は継続する
6. `UserDefaults` 使用は `PrivacyInfo.xcprivacy` で Required Reason API 宣言が必要

---

## 3. ID・命名

| 項目 | 値 | 備考 |
| --- | --- | --- |
| プロジェクト名 / PRODUCT_NAME | `KobunApp` | ASCII固定 |
| アプリ表示名（案） | 古文単語・文法特訓 | `CFBundleDisplayName`。※未確定、§12 |
| bundle ID（案） | `com.eitango.kobun` | 同一開発者アカウント内の一貫性重視。※**公開後変更不可**、提出前に確定させる |
| プロダクトID（案） | `com.eitango.kobun.unlock.full` | bundle ID に合わせる |
| 単語ID | `KOBUN_W_<KEY>` | 例 `KOBUN_W_AHARENARI`。KEY は読みのローマ字。同音異義語は `_2` 等の連番で区別 |
| 文法ID | `KOBUN_G_<KEY>` | 例 `KOBUN_G_JODOSHI_RU` |
| 文法問題ID | `KOBUN_GQ_<KEY>_<連番>` | 例 `KOBUN_GQ_JODOSHI_RU_01` |

**公開後、ID の改名は禁止**（進捗が ID キーのため、改名＝その項目の全ユーザーの履歴消失）。削除は許容（参考元のシーダーが孤児進捗を許容する設計を流用するため）。

商標: 「古文」に商標問題はない。参考元の英検商標文言に相当するものは不要。ただし「共通テスト対応」等の表記を使う場合は大学入試センターとの提携を示唆しない文言にする。

---

## 4. コンテンツ設計

### 4.1 単語（314語）

- 選定基準: 受験頻出の基本古語。多義語は主要義を `meaning` に「、」区切りで2〜3個まで
- **`word` は歴史的仮名遣いの見出し語**（あはれなり）、**`reading` は現代仮名遣いの読み**（あわれなり）を必ず持つ
  - `reading` の用途: ① TTS 読み上げ（「あはれ」をそのまま読ませると誤読する）② 単語帳の五十音順ソートキー ③ 検索対象
- 例文は古文原文（短く切り出し）+ 現代語訳 + 出典名。原文は著作権フリー（古典）なので同梱可
- 品詞: 動詞 / 形容詞 / 形容動詞 / 名詞 / 副詞 / 連語 / その他

### 4.2 文法（80項目）

| カテゴリ | 目安数 | 例 |
| --- | --- | --- |
| 助動詞 | 28 | る・らる / す・さす・しむ / き・けり / つ・ぬ / たり・り / む・むず / べし / まじ / なり(断定・伝聞) / まほし・たし … |
| 助詞 | 20 | 係助詞（ぞ・なむ・や・か・こそ）/ 接続助詞（ば・とも・ど）/ 副助詞（だに・さへ）… |
| 敬語 | 16 | 尊敬・謙譲・丁寧の主要動詞（たまふ・きこゆ・はべり…）、二方面への敬意 |
| 識別・その他 | 16 | 係り結び / 音便 / 「なり」「に」「ぬ」の識別 … |

1項目 = 1カード。フィールドは §5.2 参照。**表示順（`sortOrder`）は文法書の慣例順**（五十音ではない）。

### 4.3 文法クイズ問題バンク（125問）

文法は良質な誤選択肢の自動生成が難しいため、**4択問題を手書きで同梱**する（単語クイズは自動生成）。1問 = 問題文 + 選択肢4 + 正解番号 + 解説 + 紐づく文法項目ID。例文中の傍線部の文法的説明を問う形式を主とする。

### 4.4 無料範囲（isFree フラグ）

- 各単語・各文法項目が `isFree: Bool` を持つ。**順序依存ではなく明示フラグ**（データ編集で意図を持って決める）
- 実際の配分: **単語147語 + 助動詞カテゴリ全28項目（＝文法問題54問）**を無料。文法問題は紐づく文法項目の isFree を継承（ビルドスクリプトが伝播）
- ロックの意味は参考元と同一思想: **閲覧・検索は常に全項目可能。制限されるのは「クイズの出題対象」と「聞き流しの再生対象」だけ**。機能自体は試用後も止めない（審査リジェクト・★1回避の実績ある方針）

---

## 5. データモデル（SwiftData @Model）

参考元の「マスターはRead-Only・総入れ替え可、進捗はRead-Write・絶対保持、両者はString IDで疎結合」をそのまま踏襲。

### 5.1 WordMaster

```swift
@Model final class WordMaster {
    @Attribute(.unique) var wordId: String   // "KOBUN_W_AHARENARI"
    var word: String            // 見出し語（歴史的仮名遣い）「あはれなり」
    var reading: String         // 現代仮名遣いの読み「あわれなり」（TTS・ソート・検索用）
    var meaning: String         // 「しみじみと趣深い、感慨深い」
    var partOfSpeechRaw: String // KobunPartOfSpeech
    var example: String         // 古文例文（原文）
    var exampleTranslation: String // 例文の現代語訳
    var source: String          // 出典「枕草子」。無ければ空文字
    var isFree: Bool
    var updatedAt: Date
}
```

参考元からの削除: `frequencyCount` / `categoryRaw` / `tierRaw` / `domainRaw` / `isIdiom` / `sourceRaw`（ユーザー追加機能がないため出所区別も不要）。

### 5.2 GrammarMaster

```swift
@Model final class GrammarMaster {
    @Attribute(.unique) var grammarId: String  // "KOBUN_G_JODOSHI_RU"
    var title: String           // 「る・らる」
    var categoryRaw: String     // GrammarCategory: 助動詞/助詞/敬語/その他
    var meaning: String         // 「受身・可能・自発・尊敬」
    var connection: String      // 接続「未然形（四段・ナ変・ラ変には「る」）」。無ければ空
    var conjugation: String     // 活用「れ/れ/る/るる/るれ/れよ（下二段型）」。無ければ空
    var explanation: String     // 解説（数行。意味の見分け方など）
    var example: String         // 例文（原文）
    var exampleTranslation: String
    var isFree: Bool
    var sortOrder: Int          // 文法書順の表示ソートキー
    var updatedAt: Date
}
```

### 5.3 GrammarQuizItem

```swift
@Model final class GrammarQuizItem {
    @Attribute(.unique) var quizId: String  // "KOBUN_GQ_JODOSHI_RU_01"
    var grammarId: String       // 解説カードへのリンク（結果画面から詳細へ飛べる）
    var question: String        // 「『住み慣れし故郷』の『し』の説明として正しいものはどれか。」
    var choices: [String]       // 4択。SwiftData は Codable な配列をそのまま保存できる
    var answerIndex: Int        // 0-3
    var explanation: String
    var isFree: Bool
    var updatedAt: Date
}
```

選択肢はデータ側でも位置を散らし（`scripts/build_seed.py` が固定シードで並べ替え）、さらに出題のたびにアプリ側でも並べ替える。データが偏っていると、並べ替えを止めた瞬間に「常に1番目が正解」のクイズになるため。

### 5.4 ItemProgress（参考元 UserProgress の改名流用）

```swift
@Model final class ItemProgress {
    @Attribute(.unique) var itemId: String  // wordId または quizId（文法はクイズ問題単位でSRS管理）
    // 以下、参考元 UserProgress と完全に同一:
    // lastReviewedAt / correctCount / attemptCount / reviewBox / nextReviewAt
    // record(isCorrect:) / status / isDue / Leitner固定テーブル [0,1,3,7,14,30]日 / masteredBox=3
}
```

**参考元 `UserProgress.swift` をロジック改変なしで移植する**（プロパティ名 `wordId`→`itemId` のみ）。`SpacedRepetitionTests` も同時に移植。

- 単語の進捗キー = `wordId`
- 文法の進捗キー = **問題単位**（`quizId`）。文法項目の習熟表示は、紐づく問題群の status を集計して導出（全問 memorized → 覚えた、1問でも needsReview → 要復習、など。導出関数は純粋関数にしてテスト）

### 5.5 StudyLog（参考元をそのまま流用）

日次の解答数・正解数。ホームのミニグラフと履歴画面用。参考元の `StudyLog.swift` + `StudyHistory.swift`（純粋関数群）+ `StudyHistoryTests` を無改変移植。

---

## 6. 同梱データとビルドスクリプト

### 6.1 ソースデータ（リポジトリの `data/`、手で編集する正本）

```jsonc
// data/words.json
{ "words": [
  {
    "key": "AHARENARI",
    "word": "あはれなり",
    "reading": "あわれなり",
    "meaning": "しみじみと趣深い、感慨深い",
    "partOfSpeech": "adjectiveVerb",   // KobunPartOfSpeech の rawValue
    "example": "秋の夕暮れこそ、あはれなれ。",
    "exampleTranslation": "秋の夕暮れは、しみじみと趣深い。",
    "source": "徒然草",
    "isFree": true
  }
]}

// data/grammar.json
{ "grammar": [
  {
    "key": "JODOSHI_RU",
    "title": "る・らる",
    "category": "auxiliaryVerb",       // GrammarCategory の rawValue
    "meaning": "受身・可能・自発・尊敬",
    "connection": "未然形（四段・ナ変・ラ変には「る」、それ以外には「らる」）",
    "conjugation": "れ / れ / る / るる / るれ / れよ（下二段型）",
    "explanation": "訳し分けの目安: 直前に「〜に」があれば受身。心情語につけば自発。…",
    "example": "住み慣れし故郷、限りなく思ひ出でらる。",
    "exampleTranslation": "住み慣れた故郷のことが、この上なく自然と思い出される。",
    "isFree": true,
    "sortOrder": 10
  }
]}

// data/grammar_quiz.json
{ "questions": [
  {
    "key": "JODOSHI_RU_01",
    "grammarKey": "JODOSHI_RU",
    "question": "「故郷、思ひ出でらる」の「らる」の意味として最も適切なものはどれか。",
    "choices": ["自発", "受身", "可能", "尊敬"],
    "answerIndex": 0,
    "explanation": "「思ひ出づ」は心情動詞なので自発。…"
  }
]}
```

### 6.2 生成: `scripts/build_seed.py`

`data/*.json` を検証・結合して `KobunApp/Resources/kobun_seed.json`（`version` 番号付き）を出力する。検証項目:

- key / ID の重複なし。`grammarKey` の参照先が存在する
- 必須フィールド欠落なし（単語: reading・meaning・example・exampleTranslation。文法: meaning・explanation・example）
- クイズ: choices がちょうど4件・重複なし・`answerIndex` が 0-3
- 文法問題の `isFree` は参照先文法項目から伝播して出力
- 集計表示: 単語数 / 文法数 / 問題数 / 無料数（データ作成の進捗確認用）

### 6.3 シーダー: `KobunSeeder`

参考元 `WordMasterSeeder.swift` の方式を流用（3テーブルに拡張）:

- seed の `version` が適用済みより新しいときだけ Upsert。マスター0件なら version に関わらず再シード
- **JSON に無い ID のマスター行は削除**するが、`ItemProgress` には一切触れない（孤児進捗許容）
- version 記録は save 成功後。シード失敗はログのみで起動継続

---

## 7. 画面仕様

タブ: **ホーム / 単語帳 / クイズ / 聞き流し**（`TabRouter` 流用）。

### 7.1 ホーム

参考元 HomeView の簡略版。上から:

1. 連続学習日数 + 直近1週間のミニ棒グラフ（タップで履歴詳細へ push。参考元の History 機能一式を流用）
2. 習熟度サマリ2本: 「単語 330語中 覚えた120」「文法 150問中 覚えた40」（LearningStatus別の内訳バー。参考元の習熟度バー部品を流用）
3. 「単語クイズをはじめる」「文法クイズをはじめる」ボタン
4. 試用中は残り日数、試用後未購入は「すべての単語・文法を解放」導線（購入画面へ）

参考元にあった StudyScope カード（出題範囲設定）は**作らない**（範囲の概念がないため）。

### 7.2 単語帳

- 上部にセグメント: **単語 ⇄ 文法**
- **単語リスト**: 五十音順（`reading` ソート）。行 = 見出し語 + 意味先頭 + 習熟度アイコン。検索（word/reading/meaning 部分一致）と習熟度フィルタ（全て/未学習/要復習/学習中/覚えた）のみ
- **単語詳細**: 見出し語（読み併記）・品詞・意味・例文+訳+出典・発音ボタン（TTSで reading を読む）・習熟度と次回復習日・「覚えたことにする」「やり直す」ボタン（参考元 `markAsMemorized` / `markForReview` 流用）
- **文法リスト**: カテゴリ別セクション（助動詞/助詞/敬語/その他）、`sortOrder` 順。行 = title + meaning + 習熟度（紐づく問題群から導出）
- **文法詳細**: title・意味・接続・活用・解説・例文+訳。「この項目の問題を解く」ボタン（当該 grammarId の問題だけでクイズ開始）
- ロック中の項目も**閲覧は常に可能**（バッジ等の区別表示は出題対象外のときのみ）

### 7.3 クイズ

1. モード選択: **単語クイズ / 文法クイズ**（ホームのボタンからは選択済みで直入り）
2. 1セッション10問。出題順は `StudyQueue` 流用（①復習期限が来た項目 → ②未出題 → ③期限が近い順）
3. **単語クイズ**: 問題 = 見出し語（+例文をヒント表示可）、選択肢 = 正解の meaning + 他の単語から無作為抽出した meaning 3つ（同品詞優先、重複除外）。参考元の生成ロジック流用
4. **文法クイズ**: 問題バンクからそのまま出題（choices は同梱の4択）
5. 解答直後に正誤表示 + 解説（単語: 例文と訳 / 文法: explanation）。正誤音は参考元 `GameAudio` 流用、サウンドON/OFFトグルも流用
6. 結果画面: 正答数・間違えた問題一覧（タップで詳細へ）・「もう一度」。参考元 QuizResultView 流用
7. 出題対象 = **権利（試用中 or 購入済み or isFree）でフィルタした母集団**。試用終了後は無料範囲のみ出題され、その旨を案内（参考元のロック案内UI流用）

### 7.4 聞き流し（単語のみ）

参考元 Listening 機能（`AudioPlaybackManager` 357行 + `WordPronouncer`）を流用し、読み上げ言語を **ja-JP のみ**に変更:

- 再生単位: 「読み（reading）→ 意味 →（トグルで例文+訳）」。**歴史的仮名遣いの `word` はTTSに渡さない**（誤読するため。画面表示は `word`、音声は `reading`）
- 再生対象: 権利範囲内の全単語。順序 = 五十音順 / シャッフル切替。速度調整
- バックグラウンド再生 + ロック画面コントロール（`UIBackgroundModes: audio`、Now Playing 表示。参考元の Info.plist 構成をそのまま流用 — §2 の教訓1に注意）

### 7.5 設定・情報

タブにはせず、ホーム右上の歯車から: 購入・購入の復元 / プライバシーポリシー・サポートリンク / アプリ情報（参考元 AboutView 流用）。

---

## 8. 課金・試用

参考元の3層構造（値型で判定を分離しテスト可能にする設計）をそのまま流用:

| 型 | 役割 | 変更点 |
| --- | --- | --- |
| `AccessRights` | 権利から出題可否を決める値型 | Tier判定 → **isFree判定**に単純化: `canStudy(item) = purchased || inTrial || item.isFree` |
| `TrialManager` | 試用起点をUserDefaultsに記録。時計戻し対策込み | 無改変流用（14日） |
| `Entitlements` | StoreKitと試用の統合。`Transaction.updates` 購読（払い戻し反映） | プロダクトID差し替えのみ |

- 商品: 非消耗型1つ「全単語・全文法の出題解放」。`Products.storekit` を同梱しローカルテスト可能に
- 試用14日の根拠は参考元と同じ（7日間隔の復習に正解して「覚えた」が付く体験を試用内に完結させる）
- 価格は App Store Connect 側で設定（storekit はテスト表示用）

---

## 9. プロジェクト構成

```
kobun_app_01/
├── project.yml              # XcodeGen（参考元をコピーし名称・bundle ID変更。教訓§2を維持）
├── KobunApp/
│   ├── App/                 # KobunApp.swift / AppContainer.swift / Info.plist
│   ├── Common/              # TabRouter / CardComponents / Haptics / LearningStatus+UI 等（流用）
│   ├── Models/              # WordMaster / GrammarMaster / GrammarQuizItem / ItemProgress / StudyLog / Enums
│   ├── Repositories/        # WordRepository / GrammarRepository / ProgressRepository
│   ├── Services/
│   │   ├── DataSeeder/      # KobunSeeder
│   │   ├── Study/           # StudyQueue / StudyHistory（流用）
│   │   ├── Audio/           # GameAudio / ToneSynth（流用）
│   │   ├── TTS/             # AudioPlaybackManager / WordPronouncer（ja-JP化）
│   │   └── Purchase/        # AccessRights / TrialManager / Entitlements
│   ├── Features/
│   │   ├── Home/  ├── WordList/（LibraryView・単語詳細・文法一覧/詳細）
│   │   ├── Quiz/  ├── Listening/  ├── History/  └── Settings/（Paywall含む）
│   └── Resources/           # kobun_seed.json / Assets.xcassets / PrivacyInfo.xcprivacy
├── KobunAppTests/
├── KobunAppUITests/         # スクリーンショット撮影（CI確認用。参考元方式）
├── data/                    # words.json / grammar.json / grammar_quiz.json（正本）
├── scripts/                 # build_seed.py / make_app_icon.py（参考元流用）
├── docs/                    # 本書 / ストア提出関連
└── .github/workflows/       # ios-build.yml / testflight.yml / store-screenshots（参考元コピー）
```

`project.yml` の要点（参考元から維持）: iOS 17.0 / `INFOPLIST_FILE` 直接指定 / `PRODUCT_NAME: KobunApp` / `DEVELOPMENT_TEAM: 5PT8D8SKN8` / Automatic signing / strict concurrency complete。

---

## 10. 移植対応表（参考元ファイル → 本アプリ）

**凡例**: ◎=ほぼ無改変で流用 / ○=改変して流用 / ×=作らない / ★=新規

| 参考元 | 扱い | 備考 |
| --- | --- | --- |
| `Models/UserProgress.swift` | ◎ | `ItemProgress` に改名、`wordId`→`itemId` のみ |
| `Models/StudyLog.swift` | ◎ | |
| `Models/WordMaster.swift` | ○ | §5.1 のフィールドに変更 |
| `Models/UserWord.swift` `TypingScore.swift` | × | |
| `Models/Enums.swift` | ○ | LearningStatus◎ / PartOfSpeech→古文品詞 / Tier・Domain・FrequencyRank削除 / GrammarCategory★ |
| `Services/Study/StudyQueue.swift` | ◎ | ID抽象のまま単語・文法問題の両方に使う |
| `Services/Study/StudyHistory.swift` | ◎ | |
| `Services/Study/MasteryBreakdown.swift` | ○ | 単語/文法の2系列に |
| `Services/DataSeeder/WordMasterSeeder.swift` | ○ | 3テーブル対応の `KobunSeeder` に。堅牢化方針は維持 |
| `Services/TTS/AudioPlaybackManager.swift` | ○ | ja-JP化・reading読み上げ |
| `Services/TTS/WordPronouncer.swift` | ○ | 同上 |
| `Services/Purchase/AccessRights.swift` | ○ | Tier→isFree |
| `Services/Purchase/TrialManager.swift` `Entitlements.swift` | ◎ | ID差し替えのみ |
| `Services/Audio/GameAudio.swift` `ToneSynth.swift` | ◎ | |
| `Services/Spelling/SpellChecker.swift` | × | タイピング用 |
| `Common/`（TabRouter, CardComponents, Haptics, ConfettiView, LearningStatus+UI, SoundToggleButton, MetricExplanations 等） | ◎ | StudyScope系・WordFilter・MasteryScopeMenu は×または大幅簡素化 |
| `Features/Home/` | ○ | §7.1。Scopeカード削除、文法系列追加 |
| `Features/WordList/` | ○ | セグメント追加・文法リスト/詳細★。WordEditorView× |
| `Features/Quiz/` | ○ | 文法クイズモード追加 |
| `Features/Typing/` | × | |
| `Features/Listening/` | ○ | ja-JP化 |
| `Features/History/` | ◎ | |
| `Features/Purchase/PaywallView.swift` | ○ | 文言差し替え |
| `Features/Settings/AboutView.swift` | ○ | |
| `App/AppContainer.swift` | ○ | ModelContainer のスキーマ差し替え。フォールバック方針維持 |
| `EitangoAppTests/`（SpacedRepetition, StudyQueue, StudyHistory, QuizFlow, Entitlement, PurchaseGate, GameAudio, HomeSummary） | ○ | 対応するロジックと一緒に移植。Typing/Spelling/UserWord/StudyScope系は× |
| `EitangoAppUITests/` | ○ | 撮影対象画面を4タブ+詳細に変更 |
| `.github/workflows/` 一式 | ○ | scheme名・成果物名の差し替え |
| `scripts/make_app_icon.py` | ◎ | 元画像だけ新規 |
| `Resources/PrivacyInfo.xcprivacy` | ◎ | |

---

## 11. テスト方針

参考元と同じく「壊れても画面上は正常に見え、学習効果だけが静かに落ちる」ロジックを優先的にユニットテストする。

1. **移植テスト**: SpacedRepetitionTests / StudyQueueTests / StudyHistoryTests / QuizFlowTests / EntitlementTests / PurchaseGateTests をロジックと同時に移植し、無修正相当で通す
2. **新規テスト**:
   - 単語クイズの選択肢生成（正解重複なし・4択・同品詞優先・母集団3語以下時の縮退）
   - 文法項目の習熟度導出（問題群status→項目statusの集計関数）
   - シード検証: 同梱 `kobun_seed.json` を実際に読み、ID重複なし・文法問題の choices=4 かつ answerIndex 妥当・grammarId 参照整合・reading 全件非空
   - AccessRights の isFree ゲート
3. **UIテスト**: 各画面のスクリーンショット撮影（CIでの見た目確認 + ストア審査用素材の下地）

---

## 12. 実装状況

P1〜P6 はすべて実装済み。以下は完了時点の記録。

| Phase | 内容 | 結果 |
| --- | --- | --- |
| **P1 骨格** | project.yml / Info.plist / App / Models 5種 / KobunSeeder / data スキーマ / build_seed.py | 完了 |
| **P2 学習コア** | ContentRepository・ProgressRepository / StudyQueue / LibraryView（単語+文法）/ 単語クイズ・文法クイズ / ホーム集計 | 完了 |
| **P3 聞き流し・履歴** | AudioPlaybackManager の ja-JP 移植（reading読み上げ・例文読み上げ設定）/ StudyHistoryView | 完了。**ロック画面での再生継続だけはシミュレータで検証できないため、TestFlightでの実機確認が残っている** |
| **P4 課金** | AccessRights（isFree判定）/ TrialManager / Entitlements / PaywallView / Products.storekit | 完了。storekit を使ったローカルの購入・復元・払い戻しの確認は Mac が要る |
| **P5 データ** | 単語314語 / 文法80項目 / 文法問題125問 | 完了。`build_seed.py` の検証を通過 |
| **P6 テスト・CI** | ユニットテスト7本 / UIテスト（スクリーンショット）/ ios-build.yml / testflight.yml | 完了。**コンパイルの検証は未実施**（手元にMacもSwiftツールチェーンも無く、CIの初回実行が最初の検証になる） |

### 残っている作業

1. **CIの初回実行**（push すればビルドとテストが走る）。コンパイルエラーはここで初めて分かる
2. アイコン素材の用意と `scripts/make_app_icon.py` の移植
3. プライバシーポリシー・サポートページの公開（`AppConfig` のURLは未公開のプレースホルダ）
4. §13 の未決事項の確定

## 13. 未決事項（提出までに確定が必要）

- [ ] アプリ表示名（案: 古文単語・文法特訓）とアイコンデザイン
- [ ] bundle ID（案: `com.eitango.kobun`）— **提出後変更不可**
- [ ] 価格
- [ ] 対象読者の明記（ストア文言。高校生・受験生向けか、教養層も含むか）
- [ ] 単語330語・文法70項目の最終リスト（データ作成タスク）
