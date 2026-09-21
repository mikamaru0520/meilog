#!/usr/bin/env bash
# 初回セットアップ: XcodeGen の導入 → Xcode プロジェクト生成 → Core のテスト
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    echo "==> XcodeGen が見つからないので Homebrew でインストールします"
    brew install xcodegen
  else
    echo "XcodeGen が必要です: https://github.com/yonaskolb/XcodeGen" >&2
    exit 1
  fi
fi

echo "==> Meishi.xcodeproj を生成します"
xcodegen generate

echo "==> MeishiCore のテストを実行します"
(cd Packages/MeishiCore && swift test)

echo "==> 完了。open Meishi.xcodeproj で開けます"
echo "    project.yml の TODO（バンドル ID と Team ID）を埋めてから make generate してください"
