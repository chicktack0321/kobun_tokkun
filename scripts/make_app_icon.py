#!/usr/bin/env python3
"""アプリアイコンを生成して Assets.xcassets へ書き出す。

App Store のアイコンには決まりがある。守らないと審査ではなく
アップロードの検証で弾かれ、ビルドを上げ直すことになる。

  - 1024x1024 の正方形
  - アルファチャンネルを持たない（透過があると弾かれる）
  - 角丸を焼き込まない（Apple 側がマスクをかけるので、素材に角丸があると角に縁が残る）

元画像があればそれを変換し、無ければその場で描く。素材の差し替えに備えて
両方の経路を残している。デザインを差し替えたくなったら
下の定数を変えるか、`--source <画像>` で自前の画像から作る。

使い方:
    python scripts/make_app_icon.py                 # 描いて生成
    python scripts/make_app_icon.py --source art.png  # 元画像から生成
    python scripts/make_app_icon.py --check         # 既存アイコンの検証のみ

必要なもの: Pillow
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ICONSET = ROOT / "KobunApp/Resources/Assets.xcassets/AppIcon.appiconset"
OUT = ICONSET / "AppIcon-1024.png"

# 既定の元画像。置いてあればこれを使い、無ければその場で描く。
# パスを決め打ちにしているのは、`python scripts/make_app_icon.py` を引数なしで
# 実行したときに、いま同梱されているアイコンが再現できるようにするため。
DEFAULT_SOURCE = ROOT / "docs/assets/app-icon-source.png"

SIZE = 1024

# 配色。古典の落ち着きを出すため藍〜紺のグラデーションにし、字は生成りの白で抜く。
# 英単語アプリ（青系）と並べたときに別アプリだと分かる色味にしている。
TOP_COLOR = (28, 42, 92)      # 濃紺
BOTTOM_COLOR = (72, 52, 110)  # 紫みの藍
GLYPH_COLOR = (247, 244, 236)  # 生成り
GLYPH = "古"

# 明朝体を使う。古文という題材に合ううえ、ゴシックより字の見分けが付きやすい。
FONT_CANDIDATES = [
    "C:/Windows/Fonts/yumindb.ttf",   # 游明朝 Demibold
    "C:/Windows/Fonts/yumin.ttf",     # 游明朝
    "C:/Windows/Fonts/msmincho.ttc",  # MS 明朝
    "/System/Library/Fonts/ヒラギノ明朝 ProN.ttc",
]

# iOSのアイコンマスクの角丸半径（辺の長さに対する比）。字を置く範囲の判断に使う
MASK_RADIUS_RATIO = 0.2237


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    raise SystemExit(
        "明朝体のフォントが見つかりません。FONT_CANDIDATES に環境のフォントを足してください。"
    )


def draw_icon() -> Image.Image:
    im = Image.new("RGB", (SIZE, SIZE), TOP_COLOR)
    draw = ImageDraw.Draw(im)

    # 縦のグラデーション。1行ずつ塗る（1024行なので十分速い）
    for y in range(SIZE):
        t = y / (SIZE - 1)
        color = tuple(round(TOP_COLOR[i] + (BOTTOM_COLOR[i] - TOP_COLOR[i]) * t) for i in range(3))
        draw.line([(0, y), (SIZE, y)], fill=color)

    # 字は角丸マスクの内側に収める。マスクで削られる四隅に字が寄ると欠けて見える。
    font = load_font(int(SIZE * 0.62))
    bbox = draw.textbbox((0, 0), GLYPH, font=font)
    x = (SIZE - (bbox[2] - bbox[0])) / 2 - bbox[0]
    # 明朝体の漢字は視覚的な重心がやや上にあるので、数値上の中央より少し下げる
    y = (SIZE - (bbox[3] - bbox[1])) / 2 - bbox[1] + SIZE * 0.01
    draw.text((x, y), GLYPH, font=font, fill=GLYPH_COLOR)

    return im


def from_source(path: Path) -> Image.Image:
    im = Image.open(path)
    # 透過があると弾かれる。背景に合成してからアルファを落とす
    if im.mode in ("RGBA", "LA", "P"):
        im = im.convert("RGBA")
        background = Image.new("RGBA", im.size, TOP_COLOR + (255,))
        im = Image.alpha_composite(background, im)
    im = im.convert("RGB")
    if im.size != (SIZE, SIZE):
        im = im.resize((SIZE, SIZE), Image.LANCZOS)
    return im


def check(path: Path) -> int:
    """アップロードの検証で弾かれる条件を先に見つける"""
    if not path.exists():
        print(f"エラー: {path.relative_to(ROOT)} がありません", file=sys.stderr)
        return 1

    im = Image.open(path)
    problems = []
    if im.size != (SIZE, SIZE):
        problems.append(f"サイズが {im.size} （{SIZE}x{SIZE} でなければならない）")
    if im.mode != "RGB":
        problems.append(f"カラーモードが {im.mode}（アルファチャンネルがあると弾かれる）")

    # 角が明るいと、角丸と余白が焼き込まれている疑いがある。
    # Apple のマスクをかけたあとに角へ縁が残る。
    px = im.convert("RGB").load()
    w, h = im.size
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    if any(min(c) > 150 for c in corners):
        problems.append(f"角が明るい {corners}（角丸の余白が焼き込まれている可能性）")

    if problems:
        for p in problems:
            print(f"エラー: {p}", file=sys.stderr)
        return 1

    print(f"OK: {path.relative_to(ROOT)} {im.size} {im.mode}")
    return 0


def write_contents_json() -> None:
    """Xcode がアイコンを認識するための索引。これが無いとビルドに含まれない"""
    contents = {
        "images": [
            {"filename": OUT.name, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (ICONSET / "Contents.json").write_text(
        json.dumps(contents, indent=2) + "\n", encoding="utf-8"
    )

    # アセットカタログ自体の索引も要る
    catalog = ICONSET.parent / "Contents.json"
    if not catalog.exists():
        catalog.write_text(
            json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n",
            encoding="utf-8",
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, help="元画像から作る（省略時は描画して作る）")
    parser.add_argument("--check", action="store_true", help="既存アイコンの検証のみ")
    args = parser.parse_args()

    if args.check:
        return check(OUT)

    ICONSET.mkdir(parents=True, exist_ok=True)
    source = args.source or (DEFAULT_SOURCE if DEFAULT_SOURCE.exists() else None)
    if source:
        print(f"元画像: {Path(source).relative_to(ROOT)}")
        im = from_source(Path(source))
    else:
        print("元画像が無いため描画して作ります")
        im = draw_icon()
    # アルファを持たせないよう RGB のまま保存する
    im.save(OUT, "PNG")
    write_contents_json()
    print(f"{OUT.relative_to(ROOT)} を書き出しました")

    return check(OUT)


if __name__ == "__main__":
    sys.exit(main())
