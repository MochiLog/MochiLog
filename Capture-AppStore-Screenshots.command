#!/bin/bash
cd "$(dirname "$0")" || exit 1
python3 scripts/capture-store-screenshots.py
result=$?
if [[ $result -ne 0 ]]; then
  echo '撮影を完了できませんでした。build/store-screenshots 内のログを確認してください。'
fi
read -r -p 'Enterキーで閉じます…'
exit "$result"
