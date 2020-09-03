# MAKE_WEBP

* 指定ディレクトリ配下に `.png` があったら不可逆圧縮（品質99%）の WebP を `.png.webp` として作成するスクリプト
* 起動すると `inotify` でファイル更新を永遠に待機して、`.png` が作成・更新・削除されるのに合わせて `.png.webp` を作成・更新・削除する
* `systemd` でデーモンとして常駐させましょう
* nginx の `try_files` と組み合わせて WebP 対応のブラウザに `.png.webp` を自動配信させるととてもうれしい

