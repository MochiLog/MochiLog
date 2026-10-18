import json
import os

# 設定
input_file = "Localizable.xcstrings"
output_en = "Localizable_en.strings"
output_ja = "Localizable_ja.strings"


def load_xcstrings(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        return json.load(f)


def escape_string(s):
    if s is None:
        return ""
    return s.replace('"', '\\"').replace("\n", "\\n")


def generate_strings_file(data, lang_code, output_path):
    lines = []
    lines.append(f"/* Generated from {input_file} */\n")

    # キーでソート
    sorted_keys = sorted(data["strings"].keys())

    for key in sorted_keys:
        entry = data["strings"][key]

        # 指定言語の翻訳があるか確認
        if "localizations" in entry and lang_code in entry["localizations"]:
            unit = entry["localizations"][lang_code]
            if "stringUnit" in unit and "value" in unit["stringUnit"]:
                value = unit["stringUnit"]["value"]
                escaped_key = escape_string(key)
                escaped_value = escape_string(value)
                lines.append(f'"{escaped_key}" = "{escaped_value}";')

    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"Generated: {output_path}")


try:
    data = load_xcstrings(input_file)
    generate_strings_file(data, "en", output_en)
    generate_strings_file(data, "ja", output_ja)
    print("完了しました。")
except FileNotFoundError:
    print(f"エラー: {input_file} が見つかりません。")
except Exception as e:
    print(f"エラーが発生しました: {e}")
