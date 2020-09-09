#!/bin/bash
#set -e

SCRIPT_DIR=$(cd $(dirname $0); pwd)

source $SCRIPT_DIR/config.sh

# NO_DAEMON=1 だと指定ディレクトリ配下をWebP化だけして終了
NO_DAEMON=${NO_DAEMON:-0}
# DEBUG=1 だとだらだらとprintデバッグするよ
DEBUG=${DEBUG:-0}
# cwebp に与えるWebPのクオリティ値だよ
QUALITY=${QUALITY:-90}
# この値以上のファイルサイズのJPEGをWebPにするよ
#   0のときはJPEGはWebPにしないよ
JPEG_LARGER_THAN=${JPEG_LARGER_THAN:-0}
# TARGET_DIRS は配列でターゲットディレクトリリスト。
# ただしコマンドライン引数を与えるとそっちが優先されるよ

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

get_size() {
    local file=$1
    if [[ ! -r $file ]]; then
        echo 0
        return 0
    fi
    wc -c < $file
}

convert_image_to_webp() {
    local from_image_file=$1
    local to_webp_file=$2
    cwebp \
        -quiet \
        -q 99 \
        $from_image_file \
        -o $to_webp_file \
            > /dev/null 2>&1
}

renew_webp() {
    local file_name_base=$1
    local file_name_webp="$1.webp"
    local file_original_ext=$( get_ext "$file_name_base" )
    # * PNG
    #       * 不可逆フォーマットであり
    #         WebPの可逆フォーマットにした場合確実に大きな効果があるので
    #         かならずWebP版を作成する
    # * JPEG
    #       * 指定ファイルサイズ以上ならWebPにするといいかもしんない
    local file_original_is_jpeg=0
    if \
        [[ $file_original_ext == 'jpg' ]] \
        || [[ $file_original_ext == 'jpeg' ]] \
    ; then
        file_original_is_jpeg=1
    fi
    if \
        [[ $file_original_ext == 'png' ]] \
        || [[ $file_original_is_jpeg -eq 1 ]] \
    ; then
        :
    else
        return 0
    fi
    INFO "WebP Check: $file_name_webp"
    # WebPが古かったり存在しなかったら作業する
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
    if \
        [[ $file_original_is_jpeg -eq 1 ]] \
        && [[ $JPEG_LARGER_THAN -lt 1 ]] \
    ; then
        # JPEGはWebPにしないモード
        return 0
    fi
    local file_size=$(get_size $file_name_base)
    if \
        [[ $file_original_is_jpeg -eq 1 ]] \
        && [[ $file_size -lt $JPEG_LARGER_THAN ]] \
    ; then
        # $JPEG_LARGER_THAN より小さいJPEGは対象外
        return 0
    fi
    convert_image_to_webp "$file_name_base" "$file_name_webp"
    INFO "converted: $file_name_webp"
}

# 不要になった .(png|jpg|jpeg).webp は消す
remove_webp() {
    local file_name_base=$1
    local file_name_webp="$1.webp"
    local file_original_ext=$( get_ext "$file_name_base" )
    local file_original_is_jpeg=0
    if \
        [[ $file_original_ext == 'jpg' ]] \
        || [[ $file_original_ext == 'jpeg' ]] \
    ; then
        file_original_is_jpeg=1
    fi
    if \
        [[ $file_original_ext == 'png' ]] \
        || [[ $file_original_is_jpeg -eq 1 ]] \
    ; then
        :
    else
        return 0
    fi
    if [[ -f "$file_name_webp" ]]; then
        rm $file_name_webp
        INFO "removed: $file_name_webp"
    fi
}

# コマンドラインオプション：
# ターゲットディレクトリ内の2段階以上の拡張子をもつWebPを削除する
action_purge_all_supplemental_webp() {
    find \
        "${TARGET_DIRS[@]}" \
        -type f \
        \( \
            -iname '*.png.webp' \
            -o -iname '*.jpg.webp' \
            -o -iname '*.jpeg.webp' \
        \) \
        -print \
    | while read line
    do
        INFO "rm $line"
        rm -f "$line"
    done
    INFO "ACTION purge_all_supplemental_webp done."
}

# コマンドラインオプション：
# ターゲットディレクトリ内の png|jpg|jpeg についてすべてWebPを作成する
action_make_webp_of_all_images() {
    find \
        "${TARGET_DIRS[@]}" \
        -type f \
        \( \
            -iname '*.png' \
            -o -iname '*.jpg' \
            -o -iname '*.jpeg' \
        \) \
        -print \
    | while read line
    do
        INFO "renew $line"
        renew_webp "$line"
    done
    INFO "ACTION make_webp_of_all_images done."
}

while [[ $# -gt 0 ]]
do
    OPT="$1"
    case $OPT in
        # ターゲットディレクトリ内の png|jpg|jpeg についてすべてWebPを作成する
        # だけで終了する
        --all|-a )
            shift
            INFO '--all|-a make_webp_of_all_pngs'
            # コマンドライン指定のほうが TARGET_DIRS より優先される
            if [[ "$@" ]]; then
                TARGET_DIRS=("$@")
            fi
            action_make_webp_of_all_images
            exit
            ;;
        # ターゲットディレクトリ内の2段階以上の拡張子をもつWebPを削除する
        # だけで終了する
        --purge )
            shift
            INFO '--purge purge_all_supplemental_webp'
            # コマンドライン指定のほうが TARGET_DIRS より優先される
            if [[ "$@" ]]; then
                TARGET_DIRS=("$@")
            fi
            action_purge_all_supplemental_webp
            exit
            ;;
        *)
            break
            ;;
    esac
done

# コマンドライン指定のほうが TARGET_DIRS より優先される
if [[ "$@" ]]; then
    TARGET_DIRS=("$@")
fi

# おれはいつだって全ファイル総なめにしてWebPを作っておくんだ
action_make_webp_of_all_images

if [[ "$NO_DAEMON" -gt 0 ]]; then
    INFO 'job done. exit'
    exit
fi

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
