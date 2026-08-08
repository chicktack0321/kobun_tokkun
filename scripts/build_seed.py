#!/usr/bin/env python3
"""data/ の正本JSONを検証して、アプリ同梱の kobun_seed.json を生成する。

正本を3ファイルに分けているのは編集のしやすさのため（単語と文法を別々の人・別々の
タイミングで触れる）。アプリ側は起動時に1ファイルだけ読めばよいので、ここで結合する。

検証をこのスクリプトに集めているのは、データの不備が「実行時に静かに出題されない」
形で現れるため。ビルド前に落として気づけるようにしている。

使い方:
    python scripts/build_seed.py              # 生成
    python scripts/build_seed.py --check      # 検証のみ（CI用。ファイルを書かない）
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
OUT_PATH = ROOT / "KobunApp" / "Resources" / "kobun_seed.json"

WORD_ID_PREFIX = "KOBUN_W_"
GRAMMAR_ID_PREFIX = "KOBUN_G_"
QUIZ_ID_PREFIX = "KOBUN_GQ_"

# KobunPartOfSpeech / GrammarCategory の rawValue と一致していること。
# ここがずれると Swift 側で .other に落ちるだけで、エラーにならず気づけない。
PARTS_OF_SPEECH = {"verb", "adjective", "adjectiveVerb", "noun", "adverb", "phrase", "other"}
GRAMMAR_CATEGORIES = {"auxiliaryVerb", "particle", "honorific", "other"}

CHOICE_COUNT = 4


class ValidationError(Exception):
    pass


def load(name: str) -> dict:
    path = DATA_DIR / name
    if not path.exists():
        raise ValidationError(f"{path} がありません")
    with path.open(encoding="utf-8") as f:
        try:
            return json.load(f)
        except json.JSONDecodeError as e:
            raise ValidationError(f"{name} のJSONが壊れています: {e}") from e


def require(entry: dict, field: str, where: str) -> str:
    value = entry.get(field)
    if not isinstance(value, str) or not value.strip():
        raise ValidationError(f"{where}: 必須項目 '{field}' が空です")
    return value


def build_words(raw: dict) -> list[dict]:
    words = []
    seen_keys: set[str] = set()

    for entry in raw.get("words", []):
        key = require(entry, "key", "words")
        where = f"words[{key}]"
        if key in seen_keys:
            raise ValidationError(f"{where}: key が重複しています")
        seen_keys.add(key)

        part_of_speech = require(entry, "partOfSpeech", where)
        if part_of_speech not in PARTS_OF_SPEECH:
            raise ValidationError(f"{where}: 未知の品詞 '{part_of_speech}'")

        # reading は TTS・五十音ソート・検索の3つで使う。抜けると読み上げが
        # 歴史的仮名遣いのまま行われて誤読するので、空を許さない。
        words.append({
            "wordId": WORD_ID_PREFIX + key,
            "word": require(entry, "word", where),
            "reading": require(entry, "reading", where),
            "meaning": require(entry, "meaning", where),
            "partOfSpeech": part_of_speech,
            "example": require(entry, "example", where),
            "exampleTranslation": require(entry, "exampleTranslation", where),
            "source": entry.get("source", "") or "",
            "isFree": bool(entry.get("isFree", False)),
        })

    return words


def build_grammar(raw: dict) -> tuple[list[dict], dict[str, bool]]:
    """文法項目を組み立て、key -> isFree の表も返す（問題への伝播に使う）"""
    grammar = []
    free_by_key: dict[str, bool] = {}
    seen_orders: dict[int, str] = {}

    for entry in raw.get("grammar", []):
        key = require(entry, "key", "grammar")
        where = f"grammar[{key}]"
        if key in free_by_key:
            raise ValidationError(f"{where}: key が重複しています")

        category = require(entry, "category", where)
        if category not in GRAMMAR_CATEGORIES:
            raise ValidationError(f"{where}: 未知のカテゴリ '{category}'")

        sort_order = entry.get("sortOrder")
        if not isinstance(sort_order, int):
            raise ValidationError(f"{where}: sortOrder は整数で指定してください")
        # 並び順が重複すると表示順が実行ごとに変わりうる。文法は「接続順に並んでいること」
        # 自体が覚える手がかりなので、揺れないよう一意にしておく。
        if sort_order in seen_orders:
            raise ValidationError(
                f"{where}: sortOrder {sort_order} が {seen_orders[sort_order]} と重複しています"
            )
        seen_orders[sort_order] = key

        is_free = bool(entry.get("isFree", False))
        free_by_key[key] = is_free

        grammar.append({
            "grammarId": GRAMMAR_ID_PREFIX + key,
            "title": require(entry, "title", where),
            "category": category,
            "meaning": require(entry, "meaning", where),
            "connection": entry.get("connection", "") or "",
            "conjugation": entry.get("conjugation", "") or "",
            "explanation": require(entry, "explanation", where),
            "example": require(entry, "example", where),
            "exampleTranslation": require(entry, "exampleTranslation", where),
            "source": entry.get("source", "") or "",
            "isFree": is_free,
            "sortOrder": sort_order,
        })

    grammar.sort(key=lambda g: g["sortOrder"])
    return grammar, free_by_key


def build_quiz(raw: dict, free_by_grammar_key: dict[str, bool]) -> list[dict]:
    quiz = []
    seen_keys: set[str] = set()

    for entry in raw.get("questions", []):
        key = require(entry, "key", "questions")
        where = f"questions[{key}]"
        if key in seen_keys:
            raise ValidationError(f"{where}: key が重複しています")
        seen_keys.add(key)

        grammar_key = require(entry, "grammarKey", where)
        if grammar_key not in free_by_grammar_key:
            raise ValidationError(f"{where}: grammarKey '{grammar_key}' に対応する文法項目がありません")

        choices = entry.get("choices")
        if not isinstance(choices, list) or len(choices) != CHOICE_COUNT:
            raise ValidationError(f"{where}: choices はちょうど{CHOICE_COUNT}件必要です")
        if any(not isinstance(c, str) or not c.strip() for c in choices):
            raise ValidationError(f"{where}: choices に空の選択肢があります")
        # 同じ文言が2つあると、正解を選んでも不正解になりうる（位置で判定するため）
        if len(set(choices)) != len(choices):
            raise ValidationError(f"{where}: choices に重複があります")

        answer_index = entry.get("answerIndex")
        if not isinstance(answer_index, int) or not 0 <= answer_index < CHOICE_COUNT:
            raise ValidationError(f"{where}: answerIndex は 0〜{CHOICE_COUNT - 1} で指定してください")

        quiz.append({
            "quizId": QUIZ_ID_PREFIX + key,
            "grammarId": GRAMMAR_ID_PREFIX + grammar_key,
            "question": require(entry, "question", where),
            "choices": choices,
            "answerIndex": answer_index,
            "explanation": require(entry, "explanation", where),
            # 解説が無料なのに問題が有料だと学習が途中で途切れるため、項目側から伝播させる
            "isFree": free_by_grammar_key[grammar_key],
        })

    return quiz


def report(words: list[dict], grammar: list[dict], quiz: list[dict]) -> None:
    print(f"単語     : {len(words):4d} 件（無料 {sum(w['isFree'] for w in words)}）")
    print(f"文法項目 : {len(grammar):4d} 件（無料 {sum(g['isFree'] for g in grammar)}）")
    print(f"文法問題 : {len(quiz):4d} 件（無料 {sum(q['isFree'] for q in quiz)}）")

    # 問題が1問も無い文法項目は解説だけになり、習熟度が永遠に「未学習」のままになる。
    # 作りかけを見落とさないよう警告する（エラーにはしない。解説専用の項目もありうる）。
    quizzed = {q["grammarId"] for q in quiz}
    missing = [g["title"] for g in grammar if g["grammarId"] not in quizzed]
    if missing:
        print(f"警告: 問題が無い文法項目 {len(missing)} 件: {', '.join(missing[:10])}"
              + (" ..." if len(missing) > 10 else ""))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="検証のみ行い、ファイルを書かない")
    args = parser.parse_args()

    try:
        words = build_words(load("words.json"))
        grammar, free_by_key = build_grammar(load("grammar.json"))
        quiz = build_quiz(load("grammar_quiz.json"), free_by_key)
    except ValidationError as e:
        print(f"検証エラー: {e}", file=sys.stderr)
        return 1

    report(words, grammar, quiz)

    if args.check:
        print("検証のみ実行しました（ファイルは書いていません）")
        return 0

    # version は既存の同梱ファイルから引き継いで +1 する。
    # アプリ側は「同梱の version が適用済みより新しいとき」だけ Upsert するため、
    # 内容を変えたのに据え置くと利用者の端末へ届かない。
    version = 1
    if OUT_PATH.exists():
        with OUT_PATH.open(encoding="utf-8") as f:
            version = json.load(f).get("version", 0) + 1

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUT_PATH.open("w", encoding="utf-8") as f:
        json.dump(
            {"version": version, "words": words, "grammar": grammar, "grammarQuiz": quiz},
            f,
            ensure_ascii=False,
            indent=2,
        )
        f.write("\n")

    print(f"{OUT_PATH.relative_to(ROOT)} を version {version} で書き出しました")
    return 0


if __name__ == "__main__":
    sys.exit(main())
