# 外部アセット

## 目的

この資料では、共通基盤で使用している外部ライブラリと、その配置場所を記録する。

## Bootstrap

画面のレイアウトや部品にはBootstrapを使用している。

| 項目 | 内容 |
|---|---|
| 配布元 | [Bootstrap公式サイト](https://getbootstrap.com/) |
| version | 5.3.8 |
| ライセンス | MIT License |

Bootstrap JavaScriptのファイルから、version 5.3.8を確認した。
Bootstrap CSSについては、ファイル内からversion表記を取得できなかった。

## Bootstrapファイルの配置場所

CSSは次の場所に配置している。

```text
app/assets/stylesheets/bootstrap.min.css
```

JavaScriptは次の場所に配置している。

```text
app/assets/javascripts/bootstrap.bundle.min.js
```

## Bootstrapの読み込み方法

共通レイアウトである次のファイルから読み込んでいる。

```text
app/views/layouts/application.html.erb
```

読み込み部分は次のとおりである。

```erb
<%= stylesheet_link_tag "bootstrap.min",
                        "data-turbo-track": "reload" %>

<%= javascript_include_tag "bootstrap.bundle.min",
                           defer: true,
                           "data-turbo-track": "reload" %>
```

このコードはすでに共通レイアウトに存在するため、新しく追加する必要はない。

## TurboとStimulus

TurboとStimulusはImportmapで管理している。

設定ファイルは次のとおりである。

```text
config/importmap.rb
```

現在は次のライブラリを読み込んでいる。

- `@hotwired/turbo-rails`
- `@hotwired/stimulus`
- `@hotwired/stimulus-loading`

Stimulus Controllerは次の場所に配置する。

```text
app/javascript/controllers
```

## 外部アセットを追加するときの確認事項

外部ライブラリを追加または更新するときは、次を確認する。

- 配布元
- version
- ライセンス
- ファイルの配置場所
- 読み込み方法
- 画面表示への影響
- セキュリティ上の問題

## 更新後の確認

外部アセットを変更した場合は、次を実行する。

```bash
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
bin/rails test
bin/ci
```

画面表示やナビゲーションもブラウザで確認する。

## 注意事項

圧縮済みのCSSやJavaScriptを直接編集しない。

変更が必要な場合は、配布元の正しいファイルへ置き換え、versionやライセンスを確認する。
