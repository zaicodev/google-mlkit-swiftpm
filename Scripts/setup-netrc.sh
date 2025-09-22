#!/bin/bash

# .netrc設定スクリプト
# Qiita記事の形式に従って.netrcファイルを設定

echo "=== .netrc設定スクリプト ==="
echo "GitHubユーザー名を入力してください："
read GITHUB_USERNAME

echo "GitHub Personal Access Tokenを入力してください（表示されません）："
read -s GITHUB_TOKEN

# .netrcファイルに認証情報を記述（api.github.comとgithub.comの両方）
cat > ~/.netrc << EOF
machine api.github.com login ${GITHUB_USERNAME} password ${GITHUB_TOKEN}
machine github.com login ${GITHUB_USERNAME} password ${GITHUB_TOKEN}
EOF

# パーミッションを600に設定
chmod 600 ~/.netrc

echo ""
echo "✅ .netrcファイルの設定が完了しました"
echo "✅ パーミッションを600に設定しました"

# 設定内容の確認（トークンは隠す）
echo ""
echo "設定内容の確認："
cat ~/.netrc | sed 's/password .*/password [HIDDEN]/'

echo ""

# jqの存在確認
if ! command -v jq &> /dev/null; then
    echo "注意: jqがインストールされていないため、認証テストはスキップされます"
else
    echo "認証テストを実行しますか？ (y/n)"
    read -r response
    if [[ "$response" == "y" ]]; then
        echo "GitHub APIへの認証テスト..."
        curl -s -n https://api.github.com/user | jq -r '.login' > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "✅ 認証成功！"
            curl -s -n https://api.github.com/user | jq '{login, name, created_at}'
        else
            echo "❌ 認証失敗"
            echo "以下を確認してください："
            echo "  - GitHubユーザー名が正しいか"
            echo "  - Personal Access Tokenが正しいか"
            echo "  - トークンに適切なスコープが付与されているか"
        fi
    fi
fi