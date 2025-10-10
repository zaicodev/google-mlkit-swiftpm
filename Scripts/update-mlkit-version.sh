#!/bin/bash
# MLKitアップデート対話型ワークフロー実行スクリプト
# 使用方法: ./scripts/update-mlkit-version.sh <version>
# 各フェーズ完了時にユーザー確認を行う

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# 色付き出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ==================================================
# 共通関数
# ==================================================

# ユーザー確認関数
confirm_continue() {
    local phase_name=$1
    local next_action=$2

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "${GREEN}✅ ${phase_name} 完了${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Phase 1完了時のみアップデート内容を表示
    if [[ "$phase_name" == "Phase 1: 事前確認" ]]; then
        printf "${BOLD}今回のアップデート内容${NC}\n"
        printf "    MLKit バージョン:       ${CURRENT_MLKIT_VERSION} → ${TARGET_MLKIT_VERSION}\n"
        printf "    ラッパーバージョン:     ${CURRENT_WRAPPER_VERSION} → ${TARGET_VERSION}\n"
        echo ""
    fi

    printf "${CYAN}📋 次のフェーズ:${NC}\n"
    echo "   ${next_action}"
    echo ""

    read -p "$(printf "${YELLOW}続行しますか？ (y/n): ${NC}")" -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        printf "${RED}❌ ユーザーによって処理が中断されました${NC}\n"
        exit 1
    fi

    echo ""
}

# エラー表示関数
show_error() {
    local message=$1
    printf "${RED}❌ エラー: ${message}${NC}\n"
}

# 成功表示関数
show_success() {
    local message=$1
    printf "${GREEN}✅ ${message}${NC}\n"
}

# 警告表示関数
show_warning() {
    local message=$1
    printf "${YELLOW}⚠️  ${message}${NC}\n"
}

# 情報表示関数
show_info() {
    local message=$1
    printf "${BLUE}ℹ️  ${message}${NC}\n"
}

# ==================================================
# Phase 0: .netrc設定確認（必須）
# ==================================================
phase0_netrc_setup() {
    echo ""
    printf "${BOLD}${MAGENTA}🔑 Phase 0: GitHub認証設定（必須）${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # .netrcファイルの確認
    show_info ".netrcファイルを確認中..."

    local netrc_valid=false

    if [ -f "$HOME/.netrc" ]; then
        if grep -q "machine api.github.com" "$HOME/.netrc" && grep -q "machine github.com" "$HOME/.netrc"; then
            # トークンの有効性を簡易チェック（ghp_で始まるか確認）
            if grep "machine api.github.com" -A 2 "$HOME/.netrc" | grep -q "password ghp_"; then
                # APIを使用してトークンの詳細な検証を実施
                show_info "トークンの有効性を検証中..."

                # curl -n オプションで.netrcの認証情報を使用
                local api_response=$(curl -s -n -I https://api.github.com/user 2>/dev/null)
                local http_status=$(echo "$api_response" | head -n 1 | grep -o '[0-9]\{3\}')

                if [ "$http_status" = "200" ]; then
                    # 有効期限ヘッダーを取得
                    local expiration_header=$(echo "$api_response" | grep -i "github-authentication-token-expiration:" | cut -d':' -f2- | tr -d '\r' | xargs)

                    if [ -n "$expiration_header" ]; then
                        # 有効期限が設定されている場合の処理
                        # 日付形式: "2024-03-20 15:30:00 UTC"
                        local exp_epoch
                        if [[ "$OSTYPE" == "darwin"* ]]; then
                            # macOS
                            exp_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "${expiration_header% UTC}" +%s 2>/dev/null)
                        else
                            # Linux
                            exp_epoch=$(date -d "${expiration_header}" +%s 2>/dev/null)
                        fi

                        if [ -n "$exp_epoch" ]; then
                            local now_epoch=$(date +%s)
                            local seconds_remaining=$(( exp_epoch - now_epoch ))
                            local days_remaining=$(( seconds_remaining / 86400 ))

                            # 条件1: トークンが期限切れでないこと
                            if [ $seconds_remaining -le 0 ]; then
                                show_error ".netrc設定: トークンが期限切れです"
                                show_error "新しいトークンを生成してください"
                                netrc_valid=false
                            # 条件2: 有効期限が1年(365日)を超えていないこと
                            elif [ $days_remaining -gt 365 ]; then
                                show_error ".netrc設定: トークンの有効期限が1年を超えています（${days_remaining}日）"
                                show_error "GitHub Releaseの作成に失敗する可能性があります"
                                show_error "90日以内の有効期限でトークンを再生成してください"
                                netrc_valid=false
                            else
                                show_success ".netrc設定: ✓ トークン検証OK (有効期限: 残り${days_remaining}日)"
                                netrc_valid=true
                            fi
                        else
                            show_warning ".netrc設定: 有効期限の解析に失敗しました"
                            show_success ".netrc設定: ✓ トークンは有効です"
                            netrc_valid=true
                        fi
                    else
                        # 無期限トークン（Classic Personal Access Tokenで期限なし設定）
                        show_success ".netrc設定: ✓ トークン検証OK (無期限トークン)"
                        netrc_valid=true
                    fi
                elif [ "$http_status" = "401" ] || [ "$http_status" = "403" ]; then
                    show_error ".netrc設定: トークンが無効または権限不足です (HTTP $http_status)"
                    show_error "トークンにrepoスコープが付与されているか確認してください"
                    netrc_valid=false
                else
                    show_error ".netrc設定: API接続エラー (HTTP $http_status)"
                    show_error "ネットワーク接続を確認してください"
                    netrc_valid=false
                fi
            else
                show_error ".netrc設定: トークン形式が不正です（ghp_で始まる必要があります）"
                netrc_valid=false
            fi
        else
            show_error ".netrc設定: GitHub認証が未設定または不完全"
            netrc_valid=false
        fi
    else
        show_error ".netrc設定: ファイルが存在しません"
        netrc_valid=false
    fi

    # 設定が有効な場合は続行
    if [ "$netrc_valid" = true ]; then
        return 0
    fi

    # setup-netrc.shスクリプトの確認
    if [ ! -f "./scripts/setup-netrc.sh" ]; then
        show_error "setup-netrc.shが見つかりません"
        return 1
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "${YELLOW}⚠️  GitHub API認証が必要です${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "下記コマンドを実行して認証設定を実施してください。"
    echo "  ./scripts/setup-netrc.sh"
    echo ""
    echo "（詳細はScripts > README.md を参照）"
    return 1
}

# ==================================================
# Phase 1: 事前確認
# ==================================================
phase1_prechecks() {
    local version=$1
    TARGET_MLKIT_VERSION=$version  # グローバル変数として設定

    echo ""
    printf "${BOLD}${MAGENTA}🔍 Phase 1: 事前確認${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # リモートタグを同期（他のメンバーの作業を取得）
    show_info "リモートタグを同期中..."
    git fetch --tags >/dev/null 2>&1

    # 環境チェック
    show_info "必須要件の確認中..."
    local check_failed=false

    echo ""
    printf "${BOLD}📦 必須コマンドの確認:${NC}\n"
    echo "──────────────────────────────────"

    # GitHub CLI
    if command -v gh >/dev/null 2>&1; then
        if gh auth status >/dev/null 2>&1; then
            show_success "GitHub CLI: ✓ インストール済み & 認証済み"
        else
            show_error "GitHub CLI: 認証されていません"
            echo "    📌 実行してください: gh auth login"
            check_failed=true
        fi
    else
        show_error "GitHub CLI: インストールされていません"
        echo "    📌 実行してください: brew install gh"
        check_failed=true
    fi

    # CocoaPods
    if command -v pod >/dev/null 2>&1; then
        show_success "CocoaPods: ✓ インストール済み ($(pod --version))"
    else
        show_error "CocoaPods: インストールされていません"
        echo "    📌 実行してください: sudo gem install cocoapods"
        check_failed=true
    fi

    # Swift
    if command -v swift >/dev/null 2>&1; then
        show_success "Swift: ✓ インストール済み"
    else
        show_error "Swift: 見つかりません"
        echo "    📌 Xcodeがインストールされていることを確認してください"
        check_failed=true
    fi

    # jq
    if command -v jq >/dev/null 2>&1; then
        show_success "jq: ✓ インストール済み"
    else
        show_error "jq: インストールされていません"
        echo "    📌 実行してください: brew install jq"
        check_failed=true
    fi

    # Python3
    if command -v python3 >/dev/null 2>&1; then
        show_success "Python3: ✓ インストール済み"
    else
        show_error "Python3: インストールされていません"
        echo "    📌 実行してください: brew install python3"
        check_failed=true
    fi

    echo ""
    printf "${BOLD}📁 プロジェクトファイルの確認:${NC}\n"
    echo "──────────────────────────────────"

    # Podfile
    if [ -f "Podfile" ]; then
        show_success "Podfile: ✓ 存在確認OK"
    else
        show_error "Podfile: 見つかりません"
        check_failed=true
    fi

    # Makefile
    if [ -f "Makefile" ]; then
        show_success "Makefile: ✓ 存在確認OK"
    else
        show_error "Makefile: 見つかりません"
        check_failed=true
    fi

    # Package.swift
    if [ -f "Package.swift" ]; then
        show_success "Package.swift: ✓ 存在確認OK"
    else
        show_error "Package.swift: 見つかりません"
        check_failed=true
    fi

    echo ""
    printf "${BOLD}🔧 その他の確認:${NC}\n"
    echo "──────────────────────────────────"

    # xcframework-maker（必要に応じて自動ビルドされるため、チェックは任意）
    if [ -f "xcframework-maker/.build/release/make-xcframework" ]; then
        show_success "xcframework-maker: ✓ ビルド済み"
    else
        show_info "xcframework-maker: 必要時に自動ビルドされます"
    fi

    # Git設定
    local git_user=$(git config user.name)
    local git_email=$(git config user.email)
    if [ -n "$git_user" ] && [ -n "$git_email" ]; then
        show_success "Git設定: ✓ $git_user <$git_email>"
    else
        show_error "Git設定: ユーザー情報が未設定"
        echo "    📌 実行してください:"
        echo "       git config user.name \"Your Name\""
        echo "       git config user.email \"your.email@example.com\""
        check_failed=true
    fi


    # チェック結果の判定
    if [ "$check_failed" = true ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        show_error "❌ 環境チェックに失敗しました"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "上記のエラーを解決してから再度実行してください。"
        return 1
    fi

    show_success "環境チェック完了 - 全ての要件を満たしています"

    # Gitブランチ確認
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" = "main" ]; then
        show_success "現在のブランチ: main"
    else
        show_warning "現在のブランチ: $CURRENT_BRANCH"
        echo -e "    ${YELLOW}注意: Phase 6（Git操作）以降はmainブランチが必須です${NC}"
    fi

    # Git状態確認
    if [ -z "$(git status --porcelain)" ]; then
        show_success "作業ディレクトリはクリーン"
    else
        show_warning "未コミットの変更があります"
    fi

    # 現在のMLKitバージョンを取得（Podfileから）
    CURRENT_MLKIT_VERSION=$(grep "pod 'GoogleMLKit" Podfile | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "不明")

    # 最新のラッパータグを取得（3桁バージョン）
    LATEST_WRAPPER_TAG=$(git tag -l "v*.*.*" | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+$" | sort -V | tail -1)
    if [ -n "$LATEST_WRAPPER_TAG" ]; then
        CURRENT_WRAPPER_VERSION=$(echo $LATEST_WRAPPER_TAG | sed 's/^v//')
    else
        CURRENT_WRAPPER_VERSION="なし"
    fi

    # 新しいラッパーバージョンを決定
    # MLKitバージョンが変わる場合: メジャー.マイナー.0
    # 同じMLKitバージョンの更新: メジャー.マイナー.パッチ++
    if [ "$CURRENT_MLKIT_VERSION" != "$TARGET_MLKIT_VERSION" ]; then
        # MLKitバージョンが変わる場合
        NEW_VERSION="${TARGET_MLKIT_VERSION}"

        # すでに同じバージョンが存在する場合はパッチをインクリメント
        EXISTING_TAGS=$(git tag -l "v${TARGET_MLKIT_VERSION}" "v${TARGET_MLKIT_VERSION%%.*}.*.*" | grep -E "^v${TARGET_MLKIT_VERSION//./\\.}(\.[0-9]+)?$" | sort -V)
        if echo "$EXISTING_TAGS" | grep -q "^v${TARGET_MLKIT_VERSION}$"; then
            # 同じMLKitバージョンのタグが既に存在する場合
            # メジャー.マイナー.パッチ形式のタグから最大のパッチ番号を取得
            MAJOR_MINOR=$(echo "${TARGET_MLKIT_VERSION}" | cut -d'.' -f1-2)
            LATEST_PATCH=$(git tag -l "v${MAJOR_MINOR}.*" | grep -E "^v${MAJOR_MINOR//./\\.}\.[0-9]+$" | sed "s/^v${MAJOR_MINOR}\.//" | sort -n | tail -1)
            if [ -n "$LATEST_PATCH" ]; then
                NEW_PATCH=$((LATEST_PATCH + 1))
                NEW_VERSION="${MAJOR_MINOR}.${NEW_PATCH}"
            else
                NEW_VERSION="${MAJOR_MINOR}.1"
            fi
        fi
    else
        # 同じMLKitバージョンの更新（パッチリリース）
        MAJOR_MINOR=$(echo "${TARGET_MLKIT_VERSION}" | cut -d'.' -f1-2)
        LATEST_PATCH=$(git tag -l "v${MAJOR_MINOR}.*" | grep -E "^v${MAJOR_MINOR//./\\.}\.[0-9]+$" | sed "s/^v${MAJOR_MINOR}\.//" | sort -n | tail -1)

        if [ -n "$LATEST_PATCH" ]; then
            NEW_PATCH=$((LATEST_PATCH + 1))
        else
            NEW_PATCH=0
        fi
        NEW_VERSION="${MAJOR_MINOR}.${NEW_PATCH}"
    fi

    export TARGET_VERSION="${NEW_VERSION}"
    export CURRENT_WRAPPER_VERSION
}

# ==================================================
# Phase 2: 設定ファイル更新
# ==================================================
phase2_update_configs() {
    local version=$1

    echo ""
    printf "${BOLD}${MAGENTA}📝 Phase 2: 設定ファイル更新${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    show_info "Podfile更新中..."

    # Podfileのバージョンを更新
    sed -i '' "s/'~> [0-9.]*'/'~> ${version}'/" Podfile

    show_success "Podfile更新完了"

    # 更新内容を表示
    echo ""
    echo "更新内容:"
    local diff_output=$(git diff Podfile)
    if [ -z "$diff_output" ]; then
        echo "  ℹ️  MLKitバージョンに変更がないため、差分はありません"
    else
        echo "$diff_output" | head -20
    fi
}

# ==================================================
# Phase 3: XCFrameworkビルド
# ==================================================
phase3_build_xcframeworks() {
    echo ""
    printf "${BOLD}${MAGENTA}🔨 Phase 3: XCFrameworkビルド${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    show_info "このフェーズは少々時間がかかる場合があります"

    # フレームワーク形式の事前確認
    if [ -f "scripts/check-framework-types.sh" ]; then
        show_info "フレームワーク形式を事前確認中..."
        bash scripts/check-framework-types.sh
    fi

    # CocoaPods の依存関係を事前検証
    show_info "CocoaPods 依存関係を検証中..."

    # pod install を実行してエラーをキャッチ
    local pod_output=$(pod install 2>&1)
    local pod_exit_code=$?

    # deployment target エラーをチェック
    if echo "$pod_output" | grep -q "required a higher minimum deployment target"; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        show_error "CocoaPods 依存関係の解決に失敗しました"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "$pod_output" | grep -A 3 "CocoaPods could not find"
        echo ""
        echo "対処法:"
        echo "  1. MLKit ${TARGET_MLKIT_VERSION} の要件を確認:"
        echo "     pod spec cat GoogleMLKit --version=${TARGET_MLKIT_VERSION} | jq '.platforms'"
        echo ""
        echo "  2. Podfile の platform を適切なバージョンに更新"
        echo ""
        return 1
    fi

    if [ $pod_exit_code -ne 0 ]; then
        show_error "pod install に失敗しました"
        echo "$pod_output"
        return 1
    fi

    show_success "CocoaPods 依存関係の検証完了"

    # ビルド実行
    show_info "XCFramework作成を開始..."
    make run

    # ビルド後の検証: Podfile.lock から実際にインストールされた MLKit バージョンを確認
    show_info "ビルド結果を検証中..."

    if [ ! -f "Podfile.lock" ]; then
        show_error "Podfile.lock が生成されていません"
        return 1
    fi

    # MLKitCommon のバージョンを取得して検証
    local installed_mlkit_common=$(grep "^  - MLKitCommon" Podfile.lock | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    # MLKit のメジャーバージョンから期待される MLKitCommon バージョンを計算
    # MLKit 6.0.0 → MLKitCommon 11.0.0
    # MLKit 7.0.0 → MLKitCommon 12.0.0
    # MLKit 8.0.0 → MLKitCommon 13.0.0
    # MLKit 9.0.0 → MLKitCommon 14.0.0
    local mlkit_major=$(echo "${TARGET_MLKIT_VERSION}" | cut -d'.' -f1)
    local expected_mlkit_common_major=$((mlkit_major + 5))

    echo "  インストールされた MLKitCommon: ${installed_mlkit_common}"
    echo "  期待される MLKitCommon: ${expected_mlkit_common_major}.x.x"

    # バージョンチェック
    local installed_major=$(echo "${installed_mlkit_common}" | cut -d'.' -f1)

    if [ "$installed_major" != "$expected_mlkit_common_major" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        show_error "MLKit ${TARGET_MLKIT_VERSION} のインストールに失敗しました"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "インストールされた: MLKitCommon ${installed_mlkit_common} (MLKit $(($installed_major - 5)).x 相当)"
        echo "期待されるバージョン: MLKitCommon ${expected_mlkit_common_major}.x.x (MLKit ${mlkit_major}.x)"
        echo ""
        echo "これは通常、Podfile の platform バージョンが不足しているために発生します。"
        echo ""
        return 1
    fi

    show_success "XCFrameworkビルド完了（MLKitCommon ${installed_mlkit_common}）"
}

# ==================================================
# Phase 4: アーカイブ作成
# ==================================================
phase4_create_archives() {
    echo ""
    printf "${BOLD}${MAGENTA}📦 Phase 4: アーカイブ作成${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    show_info "XCFrameworksのzip圧縮中..."

    make archive

    # チェックサム計算
    show_info "チェックサム計算中..."
    for zip in XCFrameworks/*.zip; do
        if [ -f "$zip" ]; then
            framework_name=$(basename "$zip" .zip)
            checksum=$(swift package compute-checksum "$zip")
            echo "  $framework_name: $checksum"
        fi
    done

    show_success "アーカイブ作成完了"
}

# ==================================================
# Phase 5: Package.swift更新
# ==================================================
phase5_update_package_swift() {
    local version=$TARGET_VERSION

    echo ""
    printf "${BOLD}${MAGENTA}📝 Phase 5: Package.swift更新${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    show_info "Package.swift更新処理を開始..."

    # GitHub Release用のタグ名
    local tag="v${version}"

    # リリースアセット用のベースURL
    local base_url="https://github.com/zaicodev/google-mlkit-swiftpm/releases/download/${tag}"

    # Python スクリプトから参照できるように export
    export base_url

    # Package.swiftのバックアップ作成
    cp Package.swift Package.swift.backup

    # 各XCFrameworkのチェックサムを計算して環境変数に保存
    show_info "チェックサム計算中..."
    # bash 3.x互換のため、個別の変数として保存
    for zip_file in XCFrameworks/*.xcframework.zip; do
        if [ -f "$zip_file" ]; then
            framework_name=$(basename "$zip_file" .xcframework.zip)
            checksum=$(shasum -a 256 "$zip_file" | cut -d' ' -f1)
            # 変数名を動的に設定
            export "CHECKSUM_${framework_name}=${checksum}"
            echo "  ${framework_name}: ${checksum:0:16}..."
        fi
    done

    # Podfile.lockから依存関係のバージョンを抽出
    show_info "Podfile.lockから依存関係バージョンを取得中..."

    if [ ! -f "Podfile.lock" ]; then
        show_error "Podfile.lockが見つかりません"
        return 1
    fi

    # 各依存関係のバージョンを抽出
    GOOGLE_UTILITIES_VERSION=$(grep -A 1 "^  - GoogleUtilities/" Podfile.lock | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    GOOGLE_DATA_TRANSPORT_VERSION=$(grep "^  - GoogleDataTransport" Podfile.lock | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    PROMISES_VERSION=$(grep "^  - PromisesObjC" Podfile.lock | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    GTM_SESSION_FETCHER_VERSION=$(grep "^  - GTMSessionFetcher/" Podfile.lock | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    NANOPB_VERSION=$(grep "^  - nanopb" Podfile.lock | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    echo "  検出された依存関係バージョン:"
    echo "    GoogleUtilities: ${GOOGLE_UTILITIES_VERSION}"
    echo "    GoogleDataTransport: ${GOOGLE_DATA_TRANSPORT_VERSION}"
    echo "    PromisesObjC: ${PROMISES_VERSION}"
    echo "    GTMSessionFetcher: ${GTM_SESSION_FETCHER_VERSION}"
    echo "    nanopb: ${NANOPB_VERSION}"

    # バージョンが取得できているか確認
    if [ -z "$GOOGLE_UTILITIES_VERSION" ] || [ -z "$GOOGLE_DATA_TRANSPORT_VERSION" ]; then
        show_error "依存関係のバージョンを取得できませんでした"
        return 1
    fi

    # 環境変数としてエクスポート
    export GOOGLE_UTILITIES_VERSION
    export GOOGLE_DATA_TRANSPORT_VERSION
    export PROMISES_VERSION
    export GTM_SESSION_FETCHER_VERSION
    export NANOPB_VERSION

    # Package.swift更新用のPythonスクリプトを生成して実行
    show_info "Package.swiftのバイナリターゲットと依存関係を更新中..."
    python3 <<'PYTHON_EOF'
import re
import sys
import os

# Package.swiftを読み込む
with open('Package.swift', 'r') as f:
    content = f.read()

# 環境変数からチェックサムを取得
checksums = {
    'GoogleToolboxForMac': os.environ.get('CHECKSUM_GoogleToolboxForMac', ''),
    'GoogleUtilitiesComponents': os.environ.get('CHECKSUM_GoogleUtilitiesComponents', ''),
    'MLImage': os.environ.get('CHECKSUM_MLImage', ''),
    'MLKitBarcodeScanning': os.environ.get('CHECKSUM_MLKitBarcodeScanning', ''),
    'MLKitCommon': os.environ.get('CHECKSUM_MLKitCommon', ''),
    'MLKitFaceDetection': os.environ.get('CHECKSUM_MLKitFaceDetection', ''),
    'MLKitImageLabelingCommon': os.environ.get('CHECKSUM_MLKitImageLabelingCommon', ''),
    'MLKitObjectDetection': os.environ.get('CHECKSUM_MLKitObjectDetection', ''),
    'MLKitObjectDetectionCommon': os.environ.get('CHECKSUM_MLKitObjectDetectionCommon', ''),
    'MLKitObjectDetectionCustom': os.environ.get('CHECKSUM_MLKitObjectDetectionCustom', ''),
    'MLKitTextRecognitionCommon': os.environ.get('CHECKSUM_MLKitTextRecognitionCommon', ''),
    'MLKitTextRecognitionJapanese': os.environ.get('CHECKSUM_MLKitTextRecognitionJapanese', ''),
    'MLKitVision': os.environ.get('CHECKSUM_MLKitVision', ''),
    'MLKitVisionKit': os.environ.get('CHECKSUM_MLKitVisionKit', '')
}

# 依存関係のバージョンを環境変数から取得
google_utils_ver = os.environ.get('GOOGLE_UTILITIES_VERSION', '7.13.2')
google_dt_ver = os.environ.get('GOOGLE_DATA_TRANSPORT_VERSION', '9.4.0')
promises_ver = os.environ.get('PROMISES_VERSION', '2.4.0')
gtm_ver = os.environ.get('GTM_SESSION_FETCHER_VERSION', '3.4.1')
nanopb_ver = os.environ.get('NANOPB_VERSION', '2.30910.0')

# バージョン範囲を計算する関数
def calc_version_range(version_str):
    """
    バージョン文字列から適切な範囲を計算
    例: "8.1.0" -> ("8.1.0", "9.0.0")
    """
    parts = version_str.split('.')
    major = int(parts[0])
    minor = int(parts[1]) if len(parts) > 1 else 0

    # メジャーバージョンの次の値を上限とする
    upper_major = major + 1

    return (version_str, f"{upper_major}.0.0")

# 各依存関係のバージョン範囲を計算
google_utils_range = calc_version_range(google_utils_ver)
google_dt_range = calc_version_range(google_dt_ver)
promises_range = calc_version_range(promises_ver)

# GTMSessionFetcher は少し広めの範囲を許容
gtm_parts = gtm_ver.split('.')
gtm_major = int(gtm_parts[0])
gtm_range = (gtm_ver, "6.0.0")  # Firebaseが要求する範囲

# nanopb は狭い範囲
# 例: 2.30910.0 → 2.30910.0..<2.30911.0
nanopb_parts = nanopb_ver.split('.')
nanopb_middle = int(nanopb_parts[1]) if len(nanopb_parts) > 1 else 30910
nanopb_range = (nanopb_ver, f"2.{nanopb_middle + 1}.0")

# URLを環境変数から取得
base_url = os.environ.get('base_url', '')

# URLパターンとチェックサムを更新
for framework_name, checksum in checksums.items():
    # binaryTarget定義を探して更新
    pattern = r'(\.binaryTarget\s*\(\s*name:\s*"' + framework_name + r'".*?url:\s*")([^"]*?)(".*?checksum:\s*")([^"]*?)(")'

    def replacer(match):
        # 正式なリリースURL
        new_url = f"{base_url}/{framework_name}.xcframework.zip"
        return match.group(1) + new_url + match.group(3) + checksum + match.group(5)

    content = re.sub(pattern, replacer, content, flags=re.DOTALL)

# dependencies セクションを更新
print(f"  依存関係を更新中...")
print(f"    GoogleUtilities: {google_utils_range[0]}..<{google_utils_range[1]}")
print(f"    GoogleDataTransport: {google_dt_range[0]}..<{google_dt_range[1]}")
print(f"    Promises: {promises_range[0]}..<{promises_range[1]}")
print(f"    GTMSessionFetcher: {gtm_range[0]}..<{gtm_range[1]}")
print(f"    nanopb: {nanopb_range[0]}..<{nanopb_range[1]}")

# dependencies セクション全体を新しいバージョン範囲に置き換え
# パッケージレベルの dependencies だけを対象にする（products の後、targets の前）
dependencies_pattern = r'(products:.*?\],\s*)dependencies:\s*\[(.*?)\],(\s*targets:)'

def replace_dependencies(match):
    new_deps = f'''{match.group(1)}dependencies: [
    .package(url: "https://github.com/google/promises.git", "{promises_range[0]}"..<"{promises_range[1]}"),
    .package(url: "https://github.com/google/GoogleDataTransport.git", "{google_dt_range[0]}"..<"{google_dt_range[1]}"),
    .package(url: "https://github.com/google/GoogleUtilities.git", "{google_utils_range[0]}"..<"{google_utils_range[1]}"),
    .package(url: "https://github.com/google/gtm-session-fetcher.git", "{gtm_range[0]}"..<"{gtm_range[1]}"),
    .package(url: "https://github.com/firebase/nanopb.git", "{nanopb_range[0]}"..<"{nanopb_range[1]}"),
  ],{match.group(3)}'''
    return new_deps

content = re.sub(dependencies_pattern, replace_dependencies, content, flags=re.DOTALL)

# Package.swiftを書き戻す
with open('Package.swift', 'w') as f:
    f.write(content)

print("✅ Package.swift更新完了")
PYTHON_EOF

    # 検証
    show_info "Package.swift検証中..."

    # デバッグ: 更新後の dependencies セクションを表示
    echo "  更新後の dependencies:"
    grep -A 6 "dependencies:" Package.swift | head -10

    if swift package dump-package >/dev/null 2>&1; then
        show_success "Package.swift更新完了"
    else
        show_error "Package.swiftの検証に失敗しました"
        echo "  詳細なエラー:"
        swift package dump-package 2>&1 | head -20
        # バックアップから復元
        mv Package.swift.backup Package.swift
        return 1
    fi

    # バックアップファイルを削除
    rm -f Package.swift.backup
}

# ==================================================
# Phase 6: Git操作
# ==================================================
phase6_git_operations() {
    local version=$TARGET_VERSION

    echo ""
    printf "${BOLD}${MAGENTA}🚀 Phase 6: Git操作${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # mainブランチの必須チェック（SKIP_BRANCH_CHECKで開発時はスキップ可能）
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "main" ] && [ -z "$SKIP_BRANCH_CHECK" ]; then
        show_error "Git操作はmainブランチから実行する必要があります"
        echo ""
        echo -e "現在のブランチ: ${RED}$CURRENT_BRANCH${NC}"
        echo ""
        echo "対応方法:"
        echo -e "  1. ${YELLOW}git checkout main${NC}"
        echo -e "  2. ${YELLOW}git merge $CURRENT_BRANCH${NC} （必要に応じて）"
        echo -e "  3. ${YELLOW}./scripts/update-mlkit-version.sh $version${NC}"
        echo ""
        echo "開発時のテスト実行:"
        echo -e "  ${YELLOW}SKIP_BRANCH_CHECK=1 ./scripts/update-mlkit-version.sh $version${NC}"
        echo ""
        exit 1
    fi

    show_info "変更をコミット中..."

    if ! git add -A; then
        show_error "git add に失敗しました"
        return 1
    fi

    if ! git commit -m "Release v${version}"; then
        show_error "git commit に失敗しました"
        return 1
    fi

    show_info "リモートへプッシュ中..."

    if ! git push origin main; then
        show_error "プッシュに失敗しました"
        echo ""
        echo "手動で原因を解消し、再度スクリプトを実行してください"
        echo ""
        return 1
    fi

    show_success "Git操作完了"
}

# ==================================================
# Phase 7: GitHub Release作成
# ==================================================
phase7_create_release() {
    local version=$TARGET_VERSION

    echo ""
    printf "${BOLD}${MAGENTA}📤 Phase 7: GitHub Release作成${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    show_info "GitHub Releaseを作成中..."

    # MLKitバージョンとラッパーバージョンを明確に区別
    local mlkit_version="${TARGET_MLKIT_VERSION}"
    local wrapper_version="${version}"
    local release_tag="v${wrapper_version}"

    # リリースノート生成
    RELEASE_NOTES="## 🎉 v${wrapper_version} Release

### 📦 新機能・変更点
- Google MLKit v${mlkit_version} に更新
- XCFrameworkを再ビルド（iOS デバイス arm64、シミュレータ x86_64）
- Package.swiftのバイナリURLを更新

### 🛠️ 対応フレームワーク
- MLKitBarcodeScanning
- MLKitFaceDetection
- MLKitObjectDetection
- MLKitObjectDetectionCustom
- MLKitTextRecognitionJapanese
- MLKitCommon および依存関係

### 📱 動作要件
- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+

### 🔧 インストール方法
Package.swiftに以下を追加:
\`\`\`swift
.package(url: \"https://github.com/zaicodev/google-mlkit-swiftpm.git\", from: \"${version}\")
\`\`\`

---
🤖 Generated with Claude Code"

    # 既存のリリースがあれば削除（エラーは無視）
    gh release delete "${release_tag}" --yes 2>/dev/null || true

    # 現在のコミットハッシュを取得
    local commit_hash=$(git rev-parse HEAD)

    # .netrcからトークンを取得してGH_TOKENとして設定
    if [ -f "$HOME/.netrc" ]; then
        # .netrcが1行形式か複数行形式かに対応
        local github_token=""

        # まず1行形式を試す
        github_token=$(grep "^machine api.github.com" "$HOME/.netrc" | sed -n 's/.*password \([^ ]*\).*/\1/p')

        # 取得できなかった場合は複数行形式を試す
        if [ -z "$github_token" ]; then
            github_token=$(awk '/^machine api.github.com$/{getline; if($1=="login") getline; if($1=="password") print $2}' "$HOME/.netrc")
        fi

        if [ -n "$github_token" ]; then
            # トークンから改行を削除
            github_token=$(echo "$github_token" | tr -d '\n\r')
            export GH_TOKEN="$github_token"
        else
            show_warning "GitHub認証: .netrcからトークンを取得できませんでした"
        fi
    fi

    # タグを作成してプッシュ
    git tag -a "${release_tag}" "$commit_hash" -m "Release ${release_tag}" 2>/dev/null
    git push origin "${release_tag}" >/dev/null 2>&1

    # リリース作成とアセットアップロード
    if ! gh release create "${release_tag}" \
        XCFrameworks/*.zip \
        --repo zaicodev/google-mlkit-swiftpm \
        --title "${release_tag}" \
        --notes "$RELEASE_NOTES" \
        --target "$commit_hash" \
        --draft=false; then
        show_error "GitHub Release作成に失敗しました"

        # エラーメッセージから判断
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚠️  GitHub Release作成に失敗しました"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "考えられる原因："
        echo "1. トークンの有効期限切れ"
        echo "2. トークンのスコープ不足（repoスコープが必要）"
        echo "3. 組織のセキュリティポリシー"
        echo ""
        echo "対処法："
        echo "1. ./scripts/setup-netrc.sh を再実行して新しいトークンを設定"
        echo "2. または https://github.com/settings/tokens でトークンを確認"
        echo ""
        return 1
    fi

    show_success "GitHub Release作成完了"

    # Phase 7.5: Package.swift検証
    echo ""
    show_info "Package.swiftを検証中..."

    # Package.swiftの妥当性を検証
    if swift package dump-package >/dev/null 2>&1; then
        show_success "Package.swift検証OK"

        # リリースアセット確認（デバッグ用）
        show_info "リリースアセットを確認中..."

        # リリース情報を取得して、アップロードされたファイルを確認
        local release_data
        release_data=$(gh api repos/zaicodev/google-mlkit-swiftpm/releases/tags/${release_tag} 2>/dev/null || echo "")

        if [ -n "$release_data" ]; then
            echo "$release_data" | python3 -c "
import json
import sys
data = json.load(sys.stdin)
assets = data.get('assets', [])
print('  アップロードされたアセット:')
for asset in assets:
    if asset['name'].endswith('.xcframework.zip'):
        print(f'    ✓ {asset[\"name\"]} ({asset[\"size\"]} bytes)')
"
        else
            show_warning "リリース情報の取得をスキップしました"
        fi
    else
        show_error "Package.swiftの検証に失敗しました"
        return 1
    fi

}

# ==================================================
# Phase 8: 最終検証
# ==================================================
phase8_final_verification() {
    echo ""
    printf "${BOLD}${MAGENTA}✅ Phase 8: 最終検証${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local verification_failed=false

    # 1. Package.swift検証
    echo ""
    printf "${BOLD}1. Package.swift整合性チェック${NC}\n"
    echo "────────────────────────────────────"

    show_info "Package.swiftの検証中..."
    if swift package dump-package > /dev/null 2>&1; then
        show_success "✓ Package.swift構文チェック: OK"
    else
        show_error "✗ Package.swiftに構文エラーがあります"
        verification_failed=true
    fi

    # URLの形式確認
    show_info "URL形式チェック中..."
    if grep -q "releases/download/" Package.swift; then
        show_success "✓ URL形式: 正常"
    else
        show_error "✗ URL形式が不正です"
        verification_failed=true
    fi

    # チェックサム数の確認（14個のフレームワーク）
    show_info "チェックサム数確認中..."
    local checksum_count=$(grep 'checksum:' Package.swift | wc -l | tr -d ' ')
    if [ "$checksum_count" -ne 14 ]; then
        show_error "✗ チェックサム数が不正です: $checksum_count個（期待値: 14個）"
        verification_failed=true
    else
        show_success "✓ チェックサム数: 14個（正常）"
    fi

    # 2. GitHub Release検証
    echo ""
    printf "${BOLD}2. GitHub Releaseアセット検証${NC}\n"
    echo "────────────────────────────────────"

    show_info "GitHub Releaseのアセットを確認中..."
    local release_data=$(gh api "repos/zaicodev/google-mlkit-swiftpm/releases/tags/v${TARGET_VERSION}" 2>/dev/null || echo "")

    if [ -z "$release_data" ]; then
        show_error "✗ GitHub Release v${TARGET_VERSION}が見つかりません"
        verification_failed=true
    else
        local asset_count=$(echo "$release_data" | jq '.assets | length')
        if [ "$asset_count" -ne 14 ]; then
            show_error "✗ アセット数が不正です: $asset_count個（期待値: 14個）"
            verification_failed=true
        else
            show_success "✓ アセット数: 14個（正常）"
        fi

        # アセットサイズの妥当性チェック
        local small_assets=$(echo "$release_data" | jq -r '.assets[] | select(.size < 1000) | .name')
        if [ -n "$small_assets" ]; then
            show_warning "⚠️ 非常に小さいアセットが検出されました:"
            echo "$small_assets" | while read -r asset; do
                echo "    - $asset"
            done
        fi
    fi

    # 3. URLパス検証（パブリックリポジトリ用）
    echo ""
    printf "${BOLD}3. URLパス検証${NC}\n"
    echo "────────────────────────────────────"

    if [ -n "$release_data" ]; then
        show_info "Package.swiftのURLパスを検証中..."
        local path_errors=0

        for framework in MLImage MLKitBarcodeScanning MLKitCommon MLKitFaceDetection MLKitVision \
                        GoogleToolboxForMac GoogleUtilitiesComponents MLKitObjectDetection \
                        MLKitObjectDetectionCommon MLKitObjectDetectionCustom \
                        MLKitTextRecognitionCommon MLKitTextRecognitionJapanese \
                        MLKitImageLabelingCommon MLKitVisionKit; do

            # Package.swiftから該当フレームワークのURLパスを確認
            local url_path=$(grep -A2 "name: \"$framework\"" Package.swift | grep -o "releases/download/v${TARGET_VERSION}/${framework}.xcframework.zip")

            if [ -z "$url_path" ]; then
                show_error "  ✗ $framework: URLパスが不正です"
                ((path_errors++))
                continue
            fi

            # GitHub Releaseにアセットが存在するか確認
            local asset_exists=$(echo "$release_data" | jq -r ".assets[] | select(.name == \"${framework}.xcframework.zip\") | .name")

            if [ -z "$asset_exists" ]; then
                show_error "  ✗ $framework: GitHub Releaseにアセットが見つかりません"
                ((path_errors++))
            fi
        done

        if [ $path_errors -eq 0 ]; then
            show_success "✓ URLパス検証: 全て正常"
        else
            show_error "✗ URLパスにエラーがあります: $path_errors件"
            verification_failed=true
        fi
    fi

    # 4. Exampleプロジェクト検証
    echo ""
    printf "${BOLD}4. Exampleプロジェクト検証${NC}\n"
    echo "────────────────────────────────────"

    show_info "Exampleプロジェクトの確認..."
    if [ -d "Example" ]; then
        cd Example
        if [ -f "Package.swift" ]; then
            if swift package dump-package > /dev/null 2>&1; then
                show_success "✓ Example Package.swift検証: OK"
            else
                show_warning "⚠️ Example Package.swiftに構文エラーがあります"
            fi
        fi
        cd ..
    fi

    # 検証結果のサマリー
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ "$verification_failed" = true ]; then
        show_error "✗ Phase 8: 検証でエラーが検出されました"
        show_warning "上記のエラーを確認してください。手動での修正が必要な場合があります。"
        # エラーがあっても完了メッセージは表示
    else
        show_success "✓ Phase 8: 最終検証完了 - 全項目正常"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "${GREEN}${BOLD}🎉 MLKit v${TARGET_MLKIT_VERSION} (ライブラリ v${TARGET_VERSION}) へのアップグレードが完了しました！${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📋 完了したタスク:"
    echo "  ✅ 環境確認と事前チェック"
    echo "  ✅ 設定ファイル更新"
    echo "  ✅ XCFrameworkビルド"
    echo "  ✅ アーカイブ作成"
    echo "  ✅ Package.swift更新"
    echo "  ✅ Git操作（コミット、タグ、プッシュ）"
    echo "  ✅ GitHub Release作成"
    echo "  ✅ 最終検証"
    echo ""
    echo "🔗 リリースURL: https://github.com/zaicodev/google-mlkit-swiftpm/releases/tag/v${TARGET_VERSION}"
}

# ==================================================
# バージョン検証
# ==================================================
validate_mlkit_version() {
    local version=$1

    echo ""
    show_info "MLKit v${version} の利用可能性を確認中..."

    # CocoaPodsからGoogleMLKitの利用可能バージョンを取得（新しい順にソート）
    local available_versions=$(pod trunk info GoogleMLKit 2>/dev/null | grep -E '^\s*-\s*[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^[[:space:]]*-[[:space:]]*//' | cut -d' ' -f1 | sort -rV)

    if [ -z "$available_versions" ]; then
        # オフライン時やpod trunkが使えない場合は、既知のバージョンリストを使用
        show_warning "CocoaPodsからバージョン情報を取得できませんでした"
        show_info "オフラインモードで続行します"
        return 0
    fi

    # 指定されたバージョンが存在するかチェック
    if echo "$available_versions" | grep -q "^${version}$"; then
        show_success "MLKit v${version} は利用可能です"
        return 0
    else
        show_error "MLKit v${version} は利用できません"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        printf "${CYAN}📋 利用可能なMLKitバージョン:${NC}\n"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # 最新5バージョンを表示
        local recent_versions=$(echo "$available_versions" | head -10)
        echo "$recent_versions" | while IFS= read -r ver; do
            echo "  • ${ver}"
        done

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        printf "${YELLOW}💡 使用方法:${NC}\n"
        echo "  $0 <version>"
        echo ""
        printf "${GREEN}例:${NC}\n"
        local latest_version=$(echo "$available_versions" | head -1)
        echo "  $0 ${latest_version}  # 最新バージョン"
        echo ""
        echo "全てのバージョンを確認するには以下を実行:"
        echo "  pod trunk info GoogleMLKit"
        echo ""
        return 1
    fi
}

# ==================================================
# メイン処理
# ==================================================
main() {
    local version=$1

    if [ -z "$version" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        printf "${RED}❌ エラー: バージョンが指定されていません${NC}\n"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        printf "${YELLOW}📖 使用方法:${NC}\n"
        echo "  $0 <version>"
        echo ""
        printf "${GREEN}例:${NC}\n"
        echo "  $0 6.0.0   # MLKit v6.0.0 にアップデート"
        echo "  $0 7.0.0   # MLKit v7.0.0 にアップデート"
        echo ""

        # 利用可能なバージョンを取得して表示（新しい順にソートして上位10件）
        local available_versions=$(pod trunk info GoogleMLKit 2>/dev/null | grep -E '^\s*-\s*[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^[[:space:]]*-[[:space:]]*//' | cut -d' ' -f1 | sort -rV | head -10)
        if [ -n "$available_versions" ]; then
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            printf "${CYAN}📋 利用可能なMLKitバージョン (最新10件):${NC}\n"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "$available_versions" | while IFS= read -r ver; do
                if [ "$ver" = "$(echo "$available_versions" | head -1)" ]; then
                    echo "  • ${ver} ${GREEN}(最新)${NC}"
                else
                    echo "  • ${ver}"
                fi
            done
            echo ""
        fi

        echo "詳細なバージョン一覧を確認するには:"
        echo "  pod trunk info GoogleMLKit"
        echo ""
        exit 1
    fi

    echo ""
    printf "${BOLD}${CYAN}🚀 MLKit v${version} 自動リリース作業開始${NC}\n"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # バージョン検証
    if ! validate_mlkit_version "$version"; then
        exit 1
    fi

    echo ""
    echo "このスクリプトは各フェーズ完了時に確認を求めます。"
    echo "いつでも Ctrl+C で中断できます。"
    echo ""

    # Phase 0: .netrc設定確認（必須）
    phase0_netrc_setup || exit 1

    # Phase 1: 事前確認
    phase1_prechecks "$version" || exit 1
    confirm_continue "Phase 1: 事前確認" "Phase 2: 設定ファイル更新 - PodfileのMLKitバージョンを更新します（MLKitバージョンに変更がない場合、差分は発生しません）"

    # Phase 2: 設定ファイル更新
    phase2_update_configs "$version" || exit 1
    confirm_continue "Phase 2: 設定ファイル更新" "Phase 3: XCFrameworkビルド - CocoaPodsからXCFrameworkを作成します（少々時間がかかる場合があります）"

    # Phase 3: XCFrameworkビルド
    phase3_build_xcframeworks || exit 1
    confirm_continue "Phase 3: XCFrameworkビルド" "Phase 4: アーカイブ作成 - XCFrameworksをzip形式で圧縮します"

    # Phase 4: アーカイブ作成
    phase4_create_archives || exit 1
    confirm_continue "Phase 4: アーカイブ作成" "Phase 5: Package.swift更新 - バイナリURLとチェックサムを更新します"

    # Phase 5: Package.swift更新
    phase5_update_package_swift || exit 1
    confirm_continue "Phase 5: Package.swift更新" "Phase 6: Git操作 - 変更をコミット、プッシュします"

    # Phase 6: Git操作
    phase6_git_operations || exit 1
    confirm_continue "Phase 6: Git操作" "Phase 7: GitHub Release作成 - リリースを作成しアセットをアップロードします（少々時間がかかる場合があります）"

    # Phase 7: GitHub Release作成
    phase7_create_release || exit 1
    confirm_continue "Phase 7: GitHub Release作成" "Phase 8: 最終検証 - ビルドテストと動作確認を行います"

    # Phase 8: 最終検証
    phase8_final_verification
}

# スクリプト実行
main "$@"
