#!/bin/bash
#set -e

SCRIPT_DIR=$(cd $(dirname $0); pwd)
source $SCRIPT_DIR/config.sh

: <<_EOF_DOC
### 必要なパッケージ

* inotify
    * Alipine, Ubuntu: inotify-tools
* cwebp
    * Alpine: libwebp-tools
    * Ubuntu: webp

_EOF_DOC

INFO() {
    if [[ "$DEBUG" -eq 1 ]]; then
        echo "$@"
    fi
}

get_ext() {
    local doubtful_ext=${1##*.}
    doubtful_ext=${doubtful_ext,,}
    echo $doubtful_ext
}

convert_png_to_webp() {
    local from_png_file=$1
    local to_webp_file=$2
    cwebp \
        -quiet \
        -q 99 \
        $from_png_file \
        -o $to_webp_file \
            > /dev/null 2>&1
}

renew_webp() {
    local file_name_base=$1
    local file_name_webp="$1.webp"
    # PNGだけが不可逆フォーマットであり
    # WebPの可逆フォーマットにした場合大きな効果があるので
    # WebP版を作成する
    if [[ $( get_ext "$file_name_base" ) == 'png' ]]; then
        :
    else
        return 0
    fi
    INFO "WebP Check: $file_name_webp"
    # タイムスタンプの比較はfindでまとめて変換するときに備えて用意
    if \
        [[ -f $file_name_webp ]] \
        && [[ $file_name_webp -ot $file_name_base ]] \
    ; then
        INFO "  $file_name_webp older than original"
    elif [[ ! -f $file_name_webp ]]; then
        INFO "  WebP $file_name_webp not exists yet"
    else
        return 0
    fi
    convert_png_to_webp "$file_name_base" "$file_name_webp"
    INFO "converted: $file_name_webp"
}

# 不要になった .png.webp は消す
remove_webp() {
    local file_name_base=$1
    local file_name_webp="$1.webp"
    if [[ "$file_name_base" =~ \.png$ ]]; then
        :
    else
        return 0
    fi
    if [[ -f "$file_name_webp" ]]; then
        rm $file_name_webp
        INFO "removed: $file_name_webp"
    fi
}

# ターゲットディレクトリ内のpngについてすべてWebPを作成する
action_make_webp_of_all_pngs() {
    find \
        "${TARGET_DIRS[@]}" \
        -type f \
        -name '*.png' \
        -print \
    | while read line
    do
        INFO "$line"
        renew_webp "$line"
    done
    INFO "Find done."
}

while [[ $# -gt 0 ]]
do
    OPT="$1"
    shift
    case $OPT in
        # ターゲットディレクトリ内のpngについてすべてWebPを作成する
        # だけで終了する
        --all|-a )
            INFO '--all|-a make_webp_of_all_pngs'
            action_make_webp_of_all_pngs
            exit
            ;;
    esac
done

# おれはいつだって全ファイル総なめにしてWebPを作っておくんだ
action_make_webp_of_all_pngs

INFO 'STARTING inotifywait...'

#    --daemon \
inotifywait \
    --monitor \
    --recursive \
    --event close_write \
    --event moved_from \
    --event moved_to \
    --event delete \
    --format '%e %w%f' \
        "${TARGET_DIRS[@]}" \
| while read line
do
    notifies=($line)
    action=${notifies[0]}
    file=${notifies[1]}
    case "$action" in
        CLOSE_WRITE*|MOVED_TO )
            INFO "+ $action :: $file"
            renew_webp $file
            ;;
        DELETE|MOVED_FROM )
            INFO "- $action :: $file"
            remove_webp $file
            ;;
        * )
            INFO "??? $action :: $file"
            ;;
    esac
done

: <<_EOF_DOC_INOTIFY
INOTIFYで発生するイベント名

# 新規作成されファイルハンドルがクローズされたとき
CLOSE_WRITE,CLOSE test/test1/make
# 範囲外へ消えたとき
MOVED_FROM test/test1/make
# 範囲外から現れたとき
MOVED_TO test/test2/make
# 範囲内で移動したとき
MOVED_FROM test/test2/make
MOVED_TO test/test2/mode
# 削除
DELETE test/test2/mode
_EOF_DOC_INOTIFY
