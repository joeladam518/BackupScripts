#!/usr/bin/env bash

set -Eeo pipefail
trap cleanup SIGINT SIGTERM ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"

# Variables
SRC_PATH=""
DEST_PATH=""
TESTING="0"
COMPRESS_DURRING_TRANSFER="0"

# Functions
usage() {
    cat << EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h]

Backup your NAS

Options:
-h, --help      Print this help and exit
-t, --test      Testing mode. Adds (-n) to the rsync command
-z, --zip       Compress files during transfer
EOF
    return 0
}

cleanup() {
    trap - SIGINT SIGTERM ERR
    info="Script ended at: $(date --iso-8601="seconds")"
    echo "$info" >> "${log_path}"
    echo "$info"

    return 0
}

confirm() {
    local prompt answer response
    prompt="$(echo -e "$*")"
    read -er -t 10 -p "$prompt" answer
    for response in y Y yes Yes YES sure Sure SURE ok Ok OK
    do
        if [ "_$answer" == "_$response" ]; then
            return 0
        fi
    done

    return 1
}

choose_source_path() {
    local type dest_paths
    dest="${1:-""}" # files or media
    dest_paths=()

    if [ -z "$dest" ]; then
        echo "Invalid dest: \"$dest\"" 1>&2
        exit 1
    fi

    



}

invalid_argument() {
    echo "Invalid option: -${1} requires an argument" 1>&2
    exit 1
}

invalid_option() {
    echo "Invalid option: -${1}" 1>&2
    exit 1
}

print_info() {
    local start_ts end_ts diff
    start_ts="$(date -d "$started_at" +%s)"
    end_ts="$(date -d "$ended_at" +%s)"
    diff="$((end_ts-start_ts))"
    time="$(printf "%02dh %02dm %02ds" $((diff / 3600)) $((diff / 60 % 60)) $((diff % 60)))"

    cat << EOF

$(basename "${BASH_SOURCE[0]}")
Synced:     ${remote_path} > ${local_path}/${backup_directory}
Started at: ${started_at:-""}
Ended at:   ${ended_at:-""}
Total time: ${time}

EOF

    return 0
}


parse_long_options() {
    case "$1" in
        help) usage; exit ;;
        test) testing_mode=1 ;;
        zip) compress_durring_transfer=1 ;;
        *) invalid_option "-${OPTARG}" ;;
    esac

    return 0
}

parse_args() {
    # flags
    testing_mode=0
    compress_durring_transfer=0

    while getopts ":htz-:" opt; do
        case "$opt" in
            h) usage; exit ;;
            t) testing_mode=1 ;;
            z) compress_durring_transfer=1 ;;
            :) invalid_argument "$OPTARG" ;;
            -) parse_long_options "$OPTARG" ;;
            \?) invalid_option "$OPTARG" ;;
        esac
    done

    shift $((OPTIND - 1))

    # args
    backup_directory="${1:-""}"
    local_letter_drive="${2:-"e"}"

    return 0
}

# Start script
parse_args "$@"

log_path="${SCRIPT_DIR}/$(date "+%Y%m%d%H%M%S")-rsync.log"
exclude_path="${SCRIPT_DIR}/exclude-from.txt"
local_path="/mnt/${local_letter_drive}"
remote_path="/mnt/main/${backup_directory}"

if [ -z "$backup_directory" ] || { [ "$backup_directory" != "files" ] && [ "$backup_directory" != "media" ]; }; then
    echo "Invalid directory name: \"${backup_directory}\"" 1>&2
    exit 1
fi

if [ ! -d "$local_path" ]; then
    echo "\"$local_path\" doesn't exist" 1>&2
    exit 1
fi

if [ ! -f "$exclude_path" ]; then
    echo "\"$exclude_path\" doesn't exist" 1>&2
    exit 1
fi

# Build the rsync command
#----------------------------------------------------------------------------------------------------------------------
backup_cmd="rsync"

if [ "$testing_mode" == "1" ]; then
    backup_cmd="${backup_cmd} -n"
fi

if [ "$compress_durring_transfer" == "1" ]; then
    backup_cmd="${backup_cmd} -z"
fi

backup_cmd="${backup_cmd} -ahP -vv --delete-delay --log-file=\"${log_path}\" --exclude-from=\"${exclude_path}\""
backup_cmd="${backup_cmd} jhaker@freenas.jhaker.net:${remote_path} ${local_path}"
#----------------------------------------------------------------------------------------------------------------------

echo
echo "$backup_cmd"
echo

if confirm "Run command? (yes/No):\n> "; then
    started_at="$(date --iso-8601="seconds")"
    eval "$backup_cmd"
    ended_at="$(date --iso-8601="seconds")"

    info="$(print_info)"
    echo "$info" >> "${log_path}"
    echo "$info"
fi
