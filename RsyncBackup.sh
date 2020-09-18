#!/usr/bin/env bash

# Variables
scriptName="${0}"
testing_mode=0
compress_durring_transfer=0
script_start="$(date "+%Y-%m-%dT%H%M%S%:::z")"
log_file="${HOME}/${script_start}_rsync_log.txt"
backup_cmd="rsync"
local_dir="/mnt/i"
remote_dir="/mnt/main"

# Functions
displayHelp()
{
    echo "Usage: ${scriptName} [-t] [-h] [-z] {Files|Media}"
    echo "  -h  Display help message."
    echo "  -t  Testing Mode adds (-n) to the rsync command."
    echo "  -z  Compress files during transfer."
} 

# Options
while getopts ":htz" opt; do
    case ${opt} in
        t)
            testing_mode=1 
            ;;
        z)
            compress_durring_transfer=1
            ;;
        h) 
            displayHelp 
            exit 0
            ;;
        \?) 
            echo "Invalid Option: -${OPTARG}" 1>&2
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

if [ ! -d "$local_dir" ]; then
    echo "Can not back up to \"$local_dir\" it does not exist."
    exit 1 
fi

# Determine which remote directory to back up
what_to_backup=${1}
if [ -z "$what_to_backup" ]; then
    echo "You must tell me what to back up."
    displayHelp
    exit 1
fi

if [ "$what_to_backup" != "files" ] && [ "$what_to_backup" != "media" ]; then
    echo "Invalid Argument: ${what_to_backup}" 
    displayHelp
    exit 1
fi

remote_dir="${remote_dir}/${what_to_backup}"

# Build the rsync command
if [ "$testing_mode" == "1" ]; then
    backup_cmd="${backup_cmd} -n"
fi

if [ "$compress_durring_transfer" == "1" ]; then
    backup_cmd="${backup_cmd} -z"
fi

backup_cmd="${backup_cmd} -ahP -vvv --delete-delay --log-file=${log_file}" # --update
backup_cmd="${backup_cmd} --exclude=.recycle --exclude=System\ Volume\ Information"
backup_cmd="${backup_cmd} jhaker@freenas.jhaker.net:${remote_dir} ${local_dir}"

# Confirm, then run or not...
echo "$backup_cmd"
read -p "Run command (Yes/No)? " -t 15  answer
case ${answer} in
    [Yy]* ) eval ${backup_cmd}; break ;;
    [Nn]* ) exit 0 ;;
    * ) echo "Please answer yes or no."; exit 1 ;;
esac

# Add when the script stopped running to the bottom of the log file
script_end=$(date '+%Y-%m-%dT%H:%M:%S%:::z')
echo "" >> "$log_file"
echo "Script ended at ${script_end}" >> "$log_file"
echo "" >> "$log_file"

exit 0
