# MAKE_WEBP

* 指定ディレクトリ配下に `.png|.jpg|.jpeg` があったら不可逆圧縮（品質90%。指定可能）の WebP を `.png.webp` などとして作成するスクリプト
    * `.jpg|.jpeg` は指定サイズ以上のファイルのみに限定可能
* 起動すると `inotify` でファイル更新を永遠に待機して、`.png|.jpg|.jpeg` が作成・更新・削除されるのに合わせて `.png.webp` などを作成・更新・削除する
* `systemd` や `OpenRC` の `local` でデーモンとして常駐させましょう
* nginx の `try_files` と組み合わせて WebP 対応のブラウザに `.png.webp` を自動配信させるととてもうれしい

## 動作に必要なパッケージ類

Alpine Linux および Ubuntu での確認例。正味のところ `inotifywait` と `cwebp` があればよい。

* inotify
    * Alpine, Ubuntu: inotify-tools
* cwebp
    * Alpine: libwebp-tools
    * Ubuntu: webp

ちなみに WebP への変換速度は数値的には `cwebp` がもっとも速いもよう。

## コマンドライン

スクリプトファイルと同じディレクトリに設定ファイル `config.sh` があることを期待している。

```
./make_webp [--all|-a] [--purge] [TARGET_DIR]
```

* `--all|-a`
    * `TARGET_DIR` 内の全 `png|jpg|jpeg` 画像について WebP の作成をする
    * 処理完了後、inotify 待機しない
* `--purge`
    * `TARGET_DIR` 内の2段階以上の拡張子をもつ WebP を削除する
    * 処理完了後、inotify 待機しない
    * 本スクリプトが作成した WebP を削除することを意図しているが、**だけ** とは限らないので注意
* `TARGET_DIR`
    * 動作対象ディレクトリ
    * `config.sh` に書かれた `TARGET_DIR` よりこちらが優先される

## config.sh

スクリプトファイルと同じディレクトリに置く設定ファイル。
`config.sh.sample` を `config.sh` にコピーして使用する。
文法は bash スクリプトをただ単に `source` している。

* `TARGET_DIRS`
    * 処理対象ディレクトリ。配列で複数対応
    * 絶対パスでの記述を推奨
* `QUALITY`
    * WebP化時に指定する品質。デフォルト 90
* `JPEG_LARGER_THAN`
    * ここに指定したバイト数より大きいJPEGファイルのみWebP化する。デフォルト 500000（バイト）
    * `0` を指定するとJPEGのWebP化を **おこなわない**
* `DEBUG`
    * デバッグモード動作。`1` にするとなんか printf デバッグされる。デフォルト `0`（非デバッグモード）
* `NO_DAEMON`
    * `1` に指定すると inotify 待機に入らず終了する。指定ディレクトリ配下のファイルをすべてWebP化するために使える。デフォルト `0`（inotify待機に入る）


## nginx での設定例

まず `http` コンテキストで `conf.d/accept_webp.conf` などとしておいた以下のファイルを `include` する。`image/webp` を accept しているクライアントが来たときに変数 `$webp_suffix` を定義する目的。

```
map $http_accept $webp_suffix {
    default   "";
    "~*image/webp"  ".webp";
}
```

`server` コンテキストで `snippets/images_to_webp_try.conf` などとしておいた以下のファイルを `include` する。

```
# works with conf.d/accept_webp.conf
location ~* \.(png|jpe?g)$ {
    add_header Vary Accept;
    try_files $uri$webp_suffix $uri =404;
}
```

注意点として、この設定をおこなってもブラウザから見えるURLは「`...png`」などのままである。
実際の通信内容のみが WebP（image/webp）になる。Android版Chromeなどでは該当画像をダウンロードすると拡張子が `webp` になるので確認できる（と思う）
