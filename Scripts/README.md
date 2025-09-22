# Scripts

MLKitライブラリのバージョン更新を自動化するスクリプトです。

## update-mlkit-version.sh

MLKitを指定バージョンにアップグレードし、GitHub Releasesへの公開まで自動化します。

### 使用方法

```bash
# 基本的な使用方法
./scripts/update-mlkit-version.sh <バージョン>

# 例: v8.0.0にアップグレード
./scripts/update-mlkit-version.sh 8.0.0
```

### 実行内容

1. **環境チェック** - 必要なツールの確認
2. **Podfile更新** - MLKitバージョンを変更
3. **XCFrameworkビルド** - 全フレームワークを再ビルド
4. **アーカイブ作成** - 配布用zipファイルを生成
5. **Gitコミット** - 変更をコミット・タグ付け
6. **GitHub Release作成** - アセットをアップロード
7. **Package.swift更新** - URL/チェックサムを自動更新

### 必要な環境

- macOS
- Xcode 15.0以上
- CocoaPods 1.15.0以上
- GitHub CLI（認証済み）
- Swift 5.9以上
- .netrc設定（setup-netrc.shで設定）

### 注意事項

- 実行前に全ての変更をコミットしておくこと
- mainブランチで実行すること
- 初回実行時は.netrc設定が必要（自動プロンプト表示）

## setup-netrc.sh

GitHub APIアクセス用の.netrc設定を行うスクリプトです。

### 使用方法

```bash
./scripts/setup-netrc.sh
```

### 機能

- GitHubの個人アクセストークン（Classic, repo権限）を.netrcに設定
- トークンの有効性を自動検証
- update-mlkit-version.sh実行時に自動的に呼び出される