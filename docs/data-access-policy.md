# データアクセス方針

## 目的

この資料では、共通基盤のデータを安全に参照・登録・更新・削除するための方針を示す。

画面やControllerからデータを操作するときは、モデルに定義された関連、validation、業務用メソッドを利用する。

## 基本方針

- データの参照にはActive Recordを利用する
- SQL文字列を直接組み立てない
- 画面から受け取る値はStrong Parametersで制限する
- 登録や更新はモデルのvalidationを通す
- 複数の変更をまとめて行う場合はtransactionを利用する
- 既存の業務用メソッドがある場合は、そのメソッドを優先する
- development用DBとtest用DBを分離する

## データベース接続

development環境とproduction環境では`DATABASE_URL`を使用する。

test環境では`TEST_DATABASE_URL`を使用する。

```text
DATABASE_URL=postgresql://user:password@host:5432/database_name
TEST_DATABASE_URL=postgresql://user:password@host:5432/test_database_name
```
