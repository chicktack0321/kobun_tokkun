# 古文単語・文法特訓

大学受験向けの古文単語＋古典文法アプリ。iOS 17+ / SwiftUI / SwiftData / XcodeGen / 完全オフライン。
公開済みの英単語アプリ `C:\System_Dev\eitango_app_01` を土台にした姉妹アプリ。

- 使い方・運用手順は `README.md`
- 設計の意図と参考元からの移植方針は `docs/design.md`

## 絶対に守ること

- **ID（`KOBUN_W_*` / `KOBUN_G_*` / `KOBUN_GQ_*`）は公開後の改名禁止。** 学習履歴のキーなので、
  改名は「削除＋新規」になり、その項目の履歴が全ユーザーで失われる
- **マスターと進捗（`ItemProgress`）に `@Relationship` を張らない。** String ID での疎結合を保つ
  （マスター総入れ替え時に履歴を守るため）
- **TTSには `word`（歴史的仮名遣い）ではなく `reading`（現代仮名遣い）を渡す。** 誤読の原因になる
- **`project.yml` の `INFOPLIST_FILE` 直接指定と `PRODUCT_NAME: KobunApp`（ASCII）を維持する。**
  XcodeGen の `info:` 生成に切り替えると手書き Info.plist が上書きされ、`UIBackgroundModes` が
  抜けて聞き流しのバックグラウンド再生が静かに壊れる（参考元で実際に起きた）
- **シードのバージョン記録は `context.save()` 成功後に行う。** 逆順にすると復旧不能な状態が永続化される

## データを編集したら

`data/` の3ファイルが正本。編集後は必ず生成して出力もコミットする。

```bash
python scripts/build_seed.py
```

CIは `data/` と `KobunApp/Resources/kobun_seed.json` の一致を検証するので、生成し忘れはビルドが落ちる。

## ビルド確認

手元にMacが無いため、コンパイルの検証はGitHub Actions（`.github/workflows/ios-build.yml`）で行う。
ローカルでSwiftをビルドすることはできない。
