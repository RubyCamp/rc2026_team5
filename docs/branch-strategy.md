# ブランチ運用

## 現在の構成

共通基盤では、次のブランチを使用している。

- `main`

リモートには次のブランチが存在する。

- `origin/main`

共通基盤の確定した変更は、作業ブランチからPRを作成して`main`へ反映する。

## 基本方針

- 作業開始前に現在のブランチを確認する
- 変更内容を確認してからcommitする
- 動作確認が成功してからpushする
- `main`への変更はPRを経由する
- `main`の履歴を強制的に書き換えない
- `git push --force`は使用しない
- 他の作業者のcommitを勝手に削除しない

## 作業開始時の確認

```bash
git branch
git status
git pull --ff-only origin main
```

現在のブランチが`main`であることと、未保存の変更がないことを確認する。

本番課題では、`main`から作業ブランチを作成する。

```bash
git switch -c feature/作業内容
```

チュートリアルでは`tutorial/<GitHub-ID>`を使用し、チュートリアルの変更を`main`へマージしない。

## 変更内容の確認

```bash
git status --short
git diff
git diff --check
```

`git diff --check`で何も表示されなければ、空白や改行に関する問題はない。

## commit

変更するファイルを確認してから追加する。

```bash
git add ファイル名
git diff --cached
git commit -m "変更内容を表すメッセージ"
```

すべてのファイルを無条件で追加するのではなく、対象ファイルを確認してから`git add`する。

## pushとPR

```bash
git push -u origin HEAD
```

push後はGitHub上で`main`向けのPRを作成する。

PRでは変更内容と確認結果を記載する。

GitHubの必須承認数は0とする。PR作成後は、もう一方のグループが実装内容を確認し、必要に応じてメンターへ相談する。確認後に`main`へ反映する。

GitHub Actionsが実行された場合は、結果を確認してからマージする。

## commit履歴の確認

```bash
git log --oneline -8
```

commit URLは次のコマンドで表示できる。

```bash
echo "https://github.com/RubyCamp/rc2026_base/commit/$(git rev-parse HEAD)"
```

## 現在の主な履歴

共通基盤では、次のように機能単位でcommitしている。

- データベース定義
- 業務データの確認画面
- 静的JSONとブラウザ保存
- 変更記録の確認機能
- 初回セットアップとCI
- GitHub Actionsの修正
- system test設定の整理

## チームでbranchを追加する場合

各チームが機能branchを利用する場合は、作業内容が分かる名前を付ける。

例：

```text
feature/work-request-form
feature/staff-assignment
fix/availability-validation
```

作業完了後は、テストと差分を確認し、PRを通して`main`へ統合する。

## 禁止事項

次の操作は、担当者間で確認せずに実行しない。

```bash
git reset --hard
git push --force
git branch -D ブランチ名
```
