# テストと確認方法

## 目的

共通基盤の変更によって、既存機能、データベース、コード品質、安全性が壊れていないことを確認する。

## Railsテスト

すべてのRailsテストを実行する。

```bash
bin/rails test
```

正常な場合は、failureとerrorが0になる。

```text
0 failures, 0 errors
```

特定のファイルだけを実行する場合は、ファイル名を指定する。

```bash
bin/rails test test/models/mvp_model_test.rb
```

特定の行のテストを実行する場合は、行番号を指定する。

```bash
bin/rails test test/models/mvp_model_test.rb:39
```

## コードスタイル

```bash
bin/rubocop
```

正常な場合は次のように表示される。

```text
no offenses detected
```

## Ruby依存関係の監査

```bash
bin/bundler-audit
```

正常な場合は次のように表示される。

```text
No vulnerabilities found
```

## JavaScript依存関係の監査

```bash
bin/importmap audit
```

正常な場合は次のように表示される。

```text
No vulnerable packages found
```

## Railsコードのセキュリティ確認

```bash
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

正常な場合は、Security Warningsが0になる。

## 本番用アセットの確認

```bash
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
```

本番環境向けのCSSやJavaScriptを生成できることを確認する。

## 一括確認

```bash
bin/ci
```

`bin/ci`では次を順番に確認する。

1. 開発環境とtest DBの準備
2. RuboCop
3. Bundler Audit
4. Importmap Audit
5. Brakeman
6. 本番用アセット生成
7. test DBの初期化
8. Railsテスト
9. seedの確認
10. test DBの復元

最後に次のように表示されれば成功である。

```text
Continuous Integration passed
```

## GitHub Actions

作業ブランチをpushしてPRを作成または更新すると、GitHub Actionsが自動的に実行される。

現在のjobは次のとおりである。

- `scan_ruby`
- `scan_js`
- `lint`
- `test`

すべてのjobが緑のチェックになっていることを確認する。

system testは現在未実装であるため、GitHub Actionsの対象外としている。

## seedの確認

test環境でseedを入れ直す場合は次を実行する。

```bash
RAILS_ENV=test bin/rails db:seed:replant
```

seed実行後は、次回のテストへデータを残さないようにtest DBを準備し直す。

```bash
RAILS_ENV=test bin/rails db:test:purge
RAILS_ENV=test bin/rails db:test:prepare
```

通常はこれらを`bin/ci`が自動的に行う。

## 差分の確認

空白や改行の問題を確認する。

```bash
git diff --check
```

何も表示されなければ正常である。

変更ファイルを確認する。

```bash
git status --short
```

## commit前の最低確認

```bash
bin/rails test
bin/ci
git diff --check
git status --short
```

すべて成功してからcommitする。
