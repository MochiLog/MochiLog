#!/usr/bin/env python3
"""Combine the saved 2026-10-25 device audits without changing app data.

Inputs are the reviewed Apple audit and the original third-party snapshots in
build/device-audit-2026-10-25. Missing evidence stays missing. In particular,
simulator productClass is not physical BoardConfig, and rated mAh is not
automatically interchangeable with firmware DesignCapacity.
"""

import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[2]
OFFICIAL = ROOT / "docs/audits/device-library-2026-10-25.json"
SNAPSHOTS = ROOT / "build/device-audit-2026-10-25"
OUTPUT = ROOT / "docs/audits/device-library-combined-2026-10-25"
LIB_URL = "https://github.com/libimobiledevice/libirecovery/blob/master/src/libirecovery.c"
KIT_URL = "https://github.com/devicekit/DeviceKit/blob/master/Source/Device.generated.swift"
WATCH_URL = "https://support.apple.com/en-us/108056"


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def string_table(source, name):
    block = re.search(rf"static let {name}:.*?= \[(.*?)\n  \]", source, re.S)
    if not block:
        raise ValueError(f"Missing DeviceLibrary table: {name}")
    return dict(re.findall(r'"([^"]+)":\s*"([^"]+)"', block[1]))


def watch_name(text):
    """Normalize size/generation while retaining app-specific Cellular names."""
    if not text.startswith("Apple Watch"):
        return text
    size = re.search(r"(\d+)mm", text)
    if "Ultra" in text:
        generation = re.search(r"Ultra(?: \(第(\d+)世代\)| (\d+))?", text)
        number = next((v for v in generation.groups() if v), "1")
        return f"Apple Watch Ultra (第{number}世代)"
    if "SE" in text:
        generation = re.search(r"SE(?: \(第(\d+)世代\)| (\d+))?", text)
        number = next((v for v in generation.groups() if v), "1")
        return f"Apple Watch SE (第{number}世代) ({size[1]}mm)" if size else text
    generation = re.search(r"Apple Watch (?:Series )?(\d+)", text)
    if not generation or not size:
        return text
    result = f"Apple Watch {generation[1]} ({size[1]}mm)"
    if generation[1] in {"3", "12"} and "Cellular" in text:
        result += " Cellular"
    return result


def read_libirecovery(path):
    names, boards = defaultdict(set), defaultdict(set)
    pattern = r'\{\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*0x[\da-fA-F]+\s*,\s*0x[\da-fA-F]+\s*,\s*"([^"]+)"\s*\}'
    for identifier, board, name in re.findall(pattern, path.read_text()):
        names[identifier].add(watch_name(name))
        boards[board.lower()].add(identifier)
    return names, boards


def read_devicekit(path):
    source = path.read_text()
    labels = {}
    for documentation, case in re.findall(
        r"((?:\s*///[^\n]*\n)+)\s*case (\w+)\s*\n", source
    ):
        link = re.search(r"\[([^\]]+)\]\(https?://", documentation)
        labels[case] = link[1] if link else case
    names = {}
    for identifiers, case in re.findall(
        r'^\s*case ((?:"[^"]+"(?:, )?)+): return (\w+)\s*$', source, re.M
    ):
        label = labels.get(case, case)
        watch = re.fullmatch(r"appleWatch(Series\d+|SE\d*|Ultra\d*)(?:_(\d+)mm)?", case)
        if watch:
            family, size = watch.groups()
            if family.startswith("Series"):
                label = f"Apple Watch {family[6:]} ({size}mm)"
            elif family.startswith("SE"):
                label = f"Apple Watch SE (第{family[2:] or '1'}世代) ({size}mm)"
            else:
                label = f"Apple Watch Ultra (第{family[5:] or '1'}世代)"
        for identifier in re.findall(r'"([^"]+)"', identifiers):
            names[identifier] = label
    return names


def display(values):
    if isinstance(values, (set, list, tuple)):
        return " / ".join(str(value) for value in sorted(values, key=str)) or "記載なし"
    return values if values is not None else "記載なし"


def combine(snapshot_dir):
    official = read_json(OFFICIAL)
    appledb_file = snapshot_dir / "appledb-comparison.json"
    appledb = read_json(appledb_file)
    lib_file, kit_file = snapshot_dir / "libirecovery.c", snapshot_dir / "devicekit.swift"
    lib_names, lib_boards = read_libirecovery(lib_file)
    kit_names = read_devicekit(kit_file)
    source_path = ROOT / "MochiLog/Models/DeviceLibrary.swift"
    source = source_path.read_text()
    names = string_table(source, "deviceNamesJa")
    boards = string_table(source, "boardToIdentifier")
    soc = string_table(source, "socInfo")
    capacity_block = re.search(r"static let designCapacities:.*?= \[(.*?)\n  \]", source, re.S)[1]
    capacities = {key: int(value) for key, value in re.findall(r'"([^"]+)":\s*(\d+)', capacity_block)}
    for table, actual, snapshot_key, value_key in [
        ("names", names, "identifiers", "current"),
        ("boards", boards, "boards", "currentIdentifier"),
        ("soc", soc, "soc", "current"),
        ("capacities", capacities, "capacities", "currentDesignCapacitymAh"),
    ]:
        expected = {(r.get("key") or r.get("board") or r.get("name")): r[value_key] for r in official[snapshot_key]}
        if actual != expected:
            raise ValueError(f"Current {table} no longer matches the reviewed audit; refresh it first")

    db = {table: {r["key"]: r for r in appledb[table]} for table in ["names", "boards", "soc", "capacities", "modelNumbers"]}
    rows = []

    def add(category, key, current, apple=None, adb=None, lib=None, kit=None, xcode=None,
            status="一致", note="", difference=False, sources=None, evidence=None):
        row = dict(id=f"{category}:{key}", category=category, key=key, current=current,
                   apple=display(apple), appledb=display(adb), libirecovery=display(lib),
                   devicekit=display(kit), xcode=display(xcode), status=status, note=note,
                   difference=difference, sources=sources or [], evidence=evidence or {})
        rows.append(row)
        return row

    for item in official["identifiers"]:
        key, current = item["key"], names[item["key"]]
        reference = db["names"][key]
        status, note = "一致", "機種名の表記差とGPS/Cellularのまとめ方は正規化して比較。"
        if item["status"] == "difference":
            status, note = "誤登録・未修正", "Xcodeと第三者資料の機種名・サイズが一致。既存記録の扱いは専用マイグレーションで別途設計。"
        elif reference["status"] == "difference":
            status, note = "資料側の相違", "AppleDBは44mm。Apple公式のA2353/A2355、Xcode、libirecovery、DeviceKitは40mm。現在値を維持。"
        elif current.startswith("Apple Watch") and key in kit_names and kit_names[key] != re.sub(r" Cellular$", "", current):
            status, note = "資料側の相違", "DeviceKitのサイズがXcode・AppleDB・libirecoveryと相違。現在値を維持。"
        elif item["status"] == "unpublished-in-installed-xcode":
            status, note = "第三者資料で一致", "Apple公開資料では製品名を確認。内部IDは手元のXcodeに掲載なし。"
        elif item["status"] == "match-via-official-model-number":
            status, note = "公式モデル番号で一致", "アクセサリーA3385の公式製品情報で照合。"
        add("機種ID", key, current,
            apple=item.get("officialPublicName") or ("製品名確認・内部ID未記載" if item.get("officialProductNameConfirmed") else "内部IDは公開資料で未確認"),
            adb=reference["canonicalReference"], lib=lib_names.get(key), kit=kit_names.get(key),
            xcode=item["officialNames"], status=status, note=note,
            difference=status in {"誤登録・未修正", "資料側の相違"},
            sources=[WATCH_URL] if key.startswith("Watch") else [], evidence={"appleAudit": item, "appledbAudit": reference})

    for item in official["boards"]:
        key = item["board"]
        reference = db["boards"][key]
        exact = sorted(lib_boards.get(key.lower(), []))
        mismatch = reference["status"] == "difference"
        if mismatch and exact != reference["reference"]:
            raise ValueError(f"Board disagreement between libirecovery and AppleDB: {key}")
        xcode = "記載なし"
        if item["xcodeProductClass"]:
            xcode = f"{item['xcodeProductClass']}グループ: {display(item['xcodeRepresentedIdentifiers'])}"
        add("基板ID", key, boards[key], apple="物理基板の厳密な対応は未確認", adb=reference["reference"],
            lib=exact, xcode=xcode, status="誤登録・未修正" if mismatch else "第三者資料で一致",
            note="AppleDBとlibirecoveryの物理基板対応で照合。XcodeのproductClassは参考値で、厳密な基板対応の証拠にはしない。",
            difference=mismatch, sources=[LIB_URL, appledb["source"]["pinnedURL"]], evidence={"appleAudit": item, "appledbAudit": reference})

    for item in official["soc"]:
        key = item["name"]
        mismatch = item["status"] == "difference"
        add("SoC", key, soc[key], apple=item["official"], adb=db["soc"][key]["reference"],
            status="誤登録・未修正" if mismatch else "一致", difference=mismatch,
            note="libirecoveryのCPIDから製品名S10/S11などへの逆変換は推測で行わない。",
            sources=[item["source"]], evidence={"appleAudit": item, "appledbAudit": db["soc"][key]})

    capacity_status = {
        "same-rated-mAh": "定格値と一致",
        "regional-capacity-covered-by-existing-variant": "地域差・登録済み",
        "different-rated-mAh": "定義差・要確認",
        "Wh-only-not-converted": "Whのみ・mAh未確認",
        "mAh-not-found-in-reviewed-official-sources": "mAh未確認",
    }
    for item in official["capacities"]:
        key = item["name"]
        status = capacity_status[item["status"]]
        note = "Apple公式は定格容量。アプリは設計容量の基準値。WhからmAhへの換算は行っていない。"
        if key == "iPhone Duo":
            status, note = "修正済み", "旧4700mAhから4883mAhへ修正済み。4.0.0 (1062)。ユーザー指定によりマイグレーションなし。"
        elif status == "地域差・登録済み":
            variants = [r for r in official["capacityVariants"] if r["name"] == key]
            note = " / ".join(f"{r['configuration']}: {r['currentCapacitymAh']}mAh" for r in variants) + "。EU定格は既存の物理SIM値と一致。"
        if db["capacities"][key]["reference"] and status == "mAh未確認":
            status = "AppleDBで一致・公式mAh未確認"
        add("容量(mAh)", key, capacities[key], apple=item["officialRatedCapacitymAh"], adb=db["capacities"][key]["reference"],
            status=status, note=note, difference=status in {"修正済み", "地域差・登録済み", "定義差・要確認"},
            sources=[item["source"]] if item.get("source") else [],
            evidence={"appleAudit": item, "appledbAudit": db["capacities"][key]})

    for item in official["modelNumbers"]:
        adb = db["modelNumbers"].get(item["key"])
        add("Aモデル番号", f"{item['table']}/{item['key']}", display(item["current"]),
            apple=item["officialModelNumbersForName"], adb=adb["reference"] if adb else None,
            status="製品グループ一致", note="公式製品グループに含まれることを確認。内部IDと地域別A番号の厳密な組は公式資料だけでは未確認。",
            sources=item["sources"], evidence={"appleAudit": item, "appledbAudit": adb})

    for item in official["capacityVariants"]:
        physical = item["configuration"] == "physicalSIM"
        add("SIM別容量(mAh)", f"{item['name']}/{item['configuration']}", item["currentCapacitymAh"],
            apple=item["officialEUPhysicalSIMCapacitymAh"] if physical else None,
            status="EU物理SIM値と一致" if physical else "eSIM公式値未確認",
            note="物理SIMとeSIMは別の構成。EU物理SIMの定格値をeSIMへ流用しない。", evidence={"appleAudit": item})

    for item in official["capacityAliases"]:
        add("容量の別名参照", item["name"], item["capacityReferenceName"], status="等容量か未確認",
            note="GPS/Cellularで同容量かどうかを確認した公式資料はない。", evidence={"appleAudit": item})

    add("地域の判定", "物理SIM/eSIMの自動選択", "CH/A・ZP/Aのみ物理SIM。それ以外・情報なしはeSIM。",
        apple="EU物理SIMモデルが存在", status="判定範囲・要確認", difference=True,
        note="容量表自体の誤りとは別。EUなどの物理SIMモデルを自動選択できるか確認が必要。", evidence=official["regionSelectionObservation"])

    counts = Counter(row["status"] for row in rows)
    differences = [row for row in rows if row["difference"]]
    assert len(rows) == 605
    assert counts["誤登録・未修正"] == 20
    assert counts["資料側の相違"] == 3
    assert len(differences) == 37
    assert len({row["id"] for row in rows}) == len(rows)
    return {
        "auditDate": "2026-10-25",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "currentCommit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "currentBuild": "4.0.0 (1062)",
        "appDataChanged": False,
        "summary": {"allRows": len(rows), "differenceRows": len(differences), "statusCounts": dict(counts)},
        "definitions": [
            "誤登録20項目は機種名10・基板対応8・SoC2。重複する端末があり、20台という意味ではない。",
            "定義差8項目は設計容量と公式定格容量の相違で、誤登録とはまだ断定しない。",
            "資料側の相違3項目はAppleDB 1・DeviceKit 2。MochiLogの現在値を維持。",
            "未記載・未確認は一致として数えない。XcodeにmAhの容量定数は見つからなかった。",
            "機種名は表記とGPS/Cellularのまとめ方を正規化。容量の同一性を意味しない。",
        ],
        "sources": {
            "appleOfficial": {"auditFile": str(OFFICIAL.relative_to(ROOT)), "sha256": sha256(OFFICIAL), "retrievedSources": official["sources"]},
            "appledb": appledb["source"],
            "libirecovery": {"url": LIB_URL, "snapshotSha256": sha256(lib_file), "note": "Downloaded snapshot; upstream commit was not recorded. Hash identifies the reviewed file."},
            "devicekit": {"url": KIT_URL, "snapshotSha256": sha256(kit_file), "note": "Downloaded snapshot; upstream commit was not recorded. Hash identifies the reviewed file."},
            "xcode": {"builds": official["xcodeEvidence"]["xcodeBuilds"], "profilesScanned": 130, "appleSignaturesValid": 130, "plistsScanned": 260},
        },
        "rows": rows,
        "differences": differences,
    }


def write_outputs(data, prefix):
    prefix.parent.mkdir(parents=True, exist_ok=True)
    prefix.with_suffix(".json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    headers = ["分類", "対象", "現在値(1062)", "Apple公開資料", "AppleDB", "libirecovery", "DeviceKit", "Xcode", "判定", "補足"]
    fields = ["category", "key", "current", "apple", "appledb", "libirecovery", "devicekit", "xcode", "status", "note"]
    lines = ["MochiLog DeviceLibrary 全ソース統合差分表", "照合日: 2026-10-25 / 現在: 4.0.0 (1062)"]
    lines.extend(data["definitions"])
    lines.extend(["", "差分・注意点: 37項目", " | ".join(headers)])
    for row in data["differences"]:
        lines.append(" | ".join(str(row[field]).replace("\n", " ") for field in fields))
    lines.extend(["", "全照合: 605項目", " | ".join(headers)])
    for row in data["rows"]:
        lines.append(" | ".join(str(row[field]).replace("\n", " ") for field in fields))
    prefix.with_suffix(".txt").write_text("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshots", type=Path, default=SNAPSHOTS)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    data = combine(args.snapshots)
    write_outputs(data, args.output)
    print(json.dumps(data["summary"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
