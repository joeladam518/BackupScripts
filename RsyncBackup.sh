#!/usr/bin/env bash

# Script to backup my NAS to a local disk

set -Eeo pipefail
trap 'cleanup' SIGINT SIGTERM ERR EXIT

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd -P)"
COMPRESS_DURRING_TRANSFER="0"
EXCLUDE_PATH="${SCRIPT_DIR}/exclude-from.txt"
LOG_PATH="${SCRIPT_DIR}/$(date "+%Y%m%d%H%M%S")-rsync.log"
LOCAL_PATH=""   # destination
LOCAL_TOP_LEVEL_DIRECTORY=""
REMOTE_PATH=""  # source
SCRIPT_ARGUMENTS=()
SEARCH_PATHS=("/mnt")
SSH_HOST="jhaker@freenas.jhaker.net"
TESTING_MODE="0"
TOP_LEVEL_SUBDIRECTORIES=("files" "media")
SCRIPT_RESULT="0"
SCRIPT_STARTED_AT=""
SCRIPT_ENDED_AT=""

# Functions
usage() {
    cat << EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-l {LOCAL_PATH}] [-r {REMOTE_PATH}] [-t] [-z] [remote_path]

Backup my NAS to a local disk

Arguments
  name {files,media}          A top level remote (nas) directory name

Options:
  -h, --help                  Print this help and exit
  -l, --local {LOCAL_PATH}    The Local path to sync to
  -s, --search {SEARCH_PATHS} The paths to look for backup disks
  -t, --test                  Testing mode (Adds '-n' to the rsync command)
  -z, --zip                   Compress files during transfer (Adds '-z' to the rsync command)
EOF
    return 0
}

# shellcheck disable=SC2317
cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    info="$(basename "${BASH_SOURCE[0]}") ended at $(date "+%F %T")"
    echo "$info" >> "${LOG_PATH}"
    echo ""
    echo "$info"

    return 0
}

# shellcheck disable=SC2317
get_info() {
    local start_ts end_ts diff script_time now
    now="$(date --iso-8601="seconds")"
    start_ts="$(date -d "${SCRIPT_STARTED_AT:-"$now"}" +%s)"
    end_ts="$(date -d "${SCRIPT_ENDED_AT:-"$now"}" +%s)"
    diff="$(( end_ts - start_ts ))"
    script_time="$(printf "%02dh %02dm %02ds" $((diff / 3600)) $((diff / 60 % 60)) $((diff % 60)))"

    cat << EOF

$(basename "${BASH_SOURCE[0]}")
sync:       ${SSH_HOST}:${REMOTE_PATH:-"(unknown)"} > ${LOCAL_PATH:-"(unknown)"}
started at: $(date -d "${SCRIPT_STARTED_AT:-"$now"}" "+%F %T")
ended at:   $(date -d "${SCRIPT_ENDED_AT:-"$now"}" "+%F %T")
total time: ${script_time}

EOF

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

build_rsync_command() {
    local cmd="rsync"

    if [ "$TESTING_MODE" == "1" ]; then
        cmd="${cmd} -n"
    fi

    if [ "$COMPRESS_DURRING_TRANSFER" == "1" ]; then
        cmd="${cmd} -z"
    fi

    echo "${cmd} -ahP -vv --delete-delay --log-file=\"${LOG_PATH}\" --exclude-from=\"${EXCLUDE_PATH}\" ${SSH_HOST}:${REMOTE_PATH%/}/ ${LOCAL_PATH%/}/"

    return 0
}

invalid_path() {
    local type="${1:-""}"
    local message="Invalid ${type} path"
    local extra_info="${2:-""}"

    if [ -n "$extra_info" ]; then
        message="${message} ${extra_info}"
    fi

    echo "$message" 1>&2
    exit 1
}

is_valid_remote_directory() {
    local path="${1:-""}"

    if [[ ! "$path" =~ ^/mnt/main/(files|media).* ]]; then
        return 1
    fi

    if ! ssh "$SSH_HOST" "[ -d \"$path\" ] && [ -r \"$path\" ]"; then
        return 1
    fi

    return 0
}

is_valid_remote_top_level_directory_name() {
    local name="${1:-""}"
    local sub=""

    if [ -z "$name" ]; then
        return 1
    fi

    for sub in "${TOP_LEVEL_SUBDIRECTORIES[@]}"
    do
        if [ "_$sub" == "_$name" ]; then
            return 0
        fi
    done

    return 1
}

get_remote_paths() {
    if is_valid_remote_top_level_directory_name "$REMOTE_PATH"; then
        REMOTE_PATH="/mnt/main/${REMOTE_PATH}"
    fi

    return 0
}

is_valid_local_directory() {
    local path="${1:-""}"

    if [ -z "$path" ]; then
        return 1
    fi

    if [ ! -d "$path" ]; then
        return 1
    fi

    if [ ! -r "$path" ]; then
        return 1
    fi

    return 0
}

is_valid_local_top_level_directory() {
    local path="${1:-""}"
    local subdirectory_count=-1

    if [ -z "$path" ]; then
        return 1
    fi

    if [ ! -d "$path" ]; then
        return 1
    fi

    if [ ! -r "$path" ]; then
        return 1
    fi

    # -mindepth 1 -> dont count $path
    # -maxdepth 1 -> dont recursivly count directories
    # -not -name 'System Volume Information' -> ignore
    # -not -name '$RECYCLE.BIN' -> ignore
    # -type d -> only direcotries
    subdirectory_count="$(find "${path%/}" -mindepth 1 -maxdepth 1 -not -name 'System Volume Information' -not -name '$RECYCLE.BIN' -type d | wc -l )"

    # if it's empty its valid
    if [ "$subdirectory_count" -eq 0 ]; then
        return 0;
    fi

    # if it doesn't have the same number of directories it invalid
    if [ "$subdirectory_count" -ne ${#TOP_LEVEL_SUBDIRECTORIES[@]} ]; then
        return 1
    fi

    # make sure the subdirecories exist
    for subdirectory in "${TOP_LEVEL_SUBDIRECTORIES[@]}"
    do
        if [ ! -d "${path%/}/${subdirectory}" ] || [ ! -r "${path%/}/${subdirectory}" ]; then
            return 1
        fi
    done

    return 0
}

get_local_paths() {
    local choice=""
    local disks=()
    local disks_indexes=()
    local remote_sub_path=""
    local i=0
    local path=""
    local tries=2;

    if ! is_valid_remote_directory "$REMOTE_PATH"; then
        invalid_path "remote" "\"$REMOTE_PATH\""
    fi

    # get the remote path with out /mnt/main
    # shellcheck disable=SC2001
    remote_sub_path="$(echo "$REMOTE_PATH" | sed -e 's/^\/mnt\/main//')"
    remote_sub_path="${remote_sub_path#/}"

    if [ -n "$LOCAL_PATH" ]; then
        LOCAL_TOP_LEVEL_DIRECTORY="${LOCAL_PATH%/}"
        LOCAL_PATH="${LOCAL_TOP_LEVEL_DIRECTORY}/${remote_sub_path}"
        return 0
    fi

    # reset the local path and ask the user
    LOCAL_TOP_LEVEL_DIRECTORY=""
    LOCAL_PATH=""

    # lookn in the search paths for backup disks
    for search_path in "${SEARCH_PATHS[@]}"
    do
        for path in "$search_path"/*
        do
            if is_valid_local_top_level_directory "$path"; then
                disks+=( "$path" )
            fi
        done
    done

    echo ""

    # no disks found
    if [ ${#disks[@]} -eq 0 ]; then
        echo "Unable to find any backup disks" 1>&2
        return 1
    fi

    echo "Please choose a backup disk [0]:"

    for i in "${!disks[@]}"
    do
        disks_indexes+=( "$i" )
        echo " [${i}] ${disks[$i]}"
    done

    i=0
    while [ $i -lt $tries ]
    do
        read -r -t 10 -p "> " choice

        if [ -n "$choice" ] && grep -q "$choice" <<< "${disks_indexes[@]}"; then
            LOCAL_TOP_LEVEL_DIRECTORY="${disks[$choice]%/}"
            LOCAL_PATH="${LOCAL_TOP_LEVEL_DIRECTORY}/${remote_sub_path}"
            break
        fi

        if [ "$i" -lt $(( tries - 1 )) ]; then
            echo "Invalid choice \"$choice\"" 1>&2
            echo "Please try again"
        fi

        i=$(( i + 1 ))
    done

    return 0
}

invalid_option() {
    echo "Invalid option: ${1:-""}" 1>&2
    exit 1
}

parse_option_with_arg() {
    local short_name="${1:-""}"
    local long_name="${2:-""}"
    local option="${3:-""}"
    local next_arg="${4:-""}"

    if [ "$option" == "$short_name" ] || [ "$option" == "$long_name" ]; then
        echo "$next_arg"
    else
        # strip the option name (--[OPTION_NAME]|--[OPTION_NAME]=) from the argument
        # shellcheck disable=SC2001
        echo "$option" | sed -e 's/^[^=]*=//'
    fi

    return 0
}

parse_params() {
    local arg next_arg temp_value

    while :; do
        arg="${1:-""}"
        next_arg="${2:-""}"
        temp_value=""

        if [ -z "$arg" ]; then
            break
        fi

        case "$arg" in

            -h | --help)
                usage
                exit
                ;;
            -l | --local*)
                LOCAL_PATH="$(parse_option_with_arg "-l" "--local" "$arg" "$next_arg")"
                [ "$LOCAL_PATH" == "$next_arg" ] && shift
                ;;
            -s | --search*)
                temp_value="$(parse_option_with_arg "-s" "--search" "$arg" "$next_arg")"
                [ "$temp_value" == "$next_arg" ] && shift
                temp_value="$(echo "$temp_value" | tr ',' ' ' | tr -s ' ')"
                read -r -a SEARCH_PATHS <<< "$temp_value"
                ;;
            -t | --test)
                TESTING_MODE="1"
                ;;
            -z | --zip)
                COMPRESS_DURRING_TRANSFER="1"
                ;;
            -?*)
                invalid_option "$arg"
                ;;
            ?*)
                SCRIPT_ARGUMENTS+=("$arg")
                ;;
            *)
                break
                ;;
        esac
        shift
    done

    REMOTE_PATH="${SCRIPT_ARGUMENTS[0]:-""}"

    # parse & validate the remote directory path
    get_remote_paths

    if ! is_valid_remote_directory "$REMOTE_PATH"; then
        invalid_path "remote" "\"${REMOTE_PATH}\""
    fi

    # parse & validate the local directory path
    get_local_paths

    if ! is_valid_local_top_level_directory "$LOCAL_TOP_LEVEL_DIRECTORY"; then
        invalid_path "local top level directory" "\"${LOCAL_TOP_LEVEL_DIRECTORY}\""
    fi

    if ! is_valid_local_directory "$LOCAL_PATH"; then
        invalid_path "local" "\"${LOCAL_PATH}\""
    fi

    # make sure exclude file exists
    if [ ! -f "$EXCLUDE_PATH" ]; then
        echo "\"$EXCLUDE_PATH\" doesn't exist" 1>&2
        exit 1
    fi

    return 0
}

# Start script
#----------------------------------------------------------------------------------------------------------------------
parse_params "$@"

rsync_command="$(build_rsync_command)"

# echo the command to make sure it's correct
echo
echo "$rsync_command"
echo

if confirm "Are you sure you want to continue? (yes/No):\n> "; then
    SCRIPT_STARTED_AT="$(date --iso-8601="seconds")"
    eval "$rsync_command"
    SCRIPT_RESULT=$?
    SCRIPT_ENDED_AT="$(date --iso-8601="seconds")"
    info="$(get_info)"
    echo "$info" >> "${LOG_PATH}"
    echo "$info"
fi

exit $SCRIPT_RESULT
