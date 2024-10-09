#!/bin/bash
#Переменные
MOUNT_POINT="/mnt/backup"
BACKUP_DEVICE="/dev/sdb"
BACKUP_DIR="/backup"
USER_SURNAME="Suslov"
MAX_BACKUPS=4
#Getting the number of the first letter of the surname (Suslov = S = 19)
function get_filesystem_size() {
    local surname_letter="${USER_SURNAME:0:1}"
    local letter_position=$(echo "$surname_letter" | awk '{printf("%d\n", tolower($1))-1072}')
    echo "$letter_position"
}
#Creating a file system ext3
function create_filesystem() {
    local fs_size=$(get_filesystem_size)
    echo "Creating a file system ext3 on ${BACKUP_DEVICE}..."
    #Creating a file system on the device
    mkfs.ext3 "$BACKUP_DEVICE"
    if [ $? -eq 0 ]; then
        echo "The file system has been successfully created."
    else
        echo "Error creating the file system."
        exit 1
    fi

    mkdir -p "$MOUNT_POINT"
    echo "The mount point has been created: $MOUNT_POINT"
}
#Mounting the storage
function mount_storage() {
    echo "Mounting the storage..."
    mount "$BACKUP_DEVICE" "$MOUNT_POINT"
    if [ $? -eq 0 ]; then
        echo "The storage is mounted in: $MOUNT_POINT"
    else
        echo "Error mounting the storage."
        exit 1
    fi
}
#Unmounting the storage
function unmount_storage() {
    echo "Unmounting the storage..."
    umount "$MOUNT_POINT"
    if [ $? -eq 0 ]; then
        echo "The storage has been successfully unmounted."
    else
        echo "An error occurred when unmounting the storage."
    fi
}
#Creating a backup copy
function create_backup() {
    local source_dir="$1"
    local timestamp=$(date "+%Y-%m-%d_%H-%M-%S")
    local backup_name="${USER_SURNAME}_${timestamp}.tar.gz"
    local backup_path="${BACKUP_DIR}/${backup_name}"

    echo "Creating a backup copy: $backup_path"

    mkdir -p "$BACKUP_DIR"
    tar -czf "$backup_path" -C "$source_dir" .
    if [ $? -eq 0 ]; then
        echo "The backup was successfully created."
    else
        echo "Error when creating a backup."
    fi

    cleanup_backups
}
#Cleaning up old backups (storing the latest MAX_BACKUPS copies)
function cleanup_backups() {
    local backups=( $(ls -t "$BACKUP_DIR"/*.tar.gz) )
    local backups_count=${#backups[@]}

    if [ "$backups_count" -gt "$MAX_BACKUPS" ]; then
        local backups_to_delete=$(($backups_count - $MAX_BACKUPS))
        for ((i=backups_count-1; i>=MAX_BACKUPS; i--)); do
            echo "Deleting an old backup: ${backups[$i]}"
            rm -f "${backups[$i]}"
        done
    fi
}
#Setting up a Backup task
function setup_backup_task() {
    echo "Enter the path to the backup directory:"
    read -r source_dir

    echo "Select a schedule (1 - once a minute, 2 - once every 5 minutes, 3 - once a day):"
    read -r schedule_option

    local schedule=""
    case "$schedule_option" in
        1) schedule="* * * * *" ;;
        2) schedule="*/5 * * * *" ;;
        3) schedule="0 0 * * *" ;;
        *) echo "Wrong choice."; exit 1 ;;
    esac

    local cron_job="$schedule root mount $BACKUP_DEVICE $MOUNT_POINT && tar -czf $BACKUP_DIR/${USER_SURNAME}_\$(date +\%F_\%T).tar.gz -C $source_dir . && umount $MOUNT_POINT"
    
    echo "Setting up a cron task..."
    echo "$cron_job" | sudo tee /etc/cron.d/backup_task > /dev/null
    chmod 0644 /etc/cron.d/backup_task
    systemctl restart cron

    echo "The backup task has been successfully configured."
}
#Restoring a backup
function restore_backup() {
    local backups=( $(ls "$BACKUP_DIR"/*.tar.gz 2>/dev/null) )
    local backups_count=${#backups[@]}

    if [ "$backups_count" -eq 0 ]; then
        echo "There are no backups available."
        return
    fi

    echo "Available backups:"
    for ((i=0; i<backups_count; i++)); do
        echo "$((i+1)). ${backups[$i]}"
    done

    echo "Select the backup number to restore:"
    read -r choice
if [ "$choice" -gt 0 ] && [ "$choice" -le "$backups_count" ]; then
        local backup_to_restore="${backups[$((choice-1))]}"
        echo "Enter the recovery path:"
        read -r restore_path

        echo "Recover ${backup_to_restore} in ${restore_path}"
        mkdir -p "$restore_path"
        tar -xzf "$backup_to_restore" -C "$restore_path"
        if [ $? -eq 0 ]; then
            echo "The backup was successfully restored."
        else
            echo "Error during recovery."
        fi
    else
        echo "Wrong choice."
    fi
}
#Main menu
function main_menu() {
    while true; do
        echo "
        1. Create storage
        2. Create a backup task
        3. Restore a backup
        4. Exit
        "
        read -r choice

        case "$choice" in
            1) create_filesystem ;;
            2) setup_backup_task ;;
            3) restore_backup ;;
            4) exit 0 ;;
            *) echo "Wrong choice." ;;
        esac
    done
}
#Launch a main menu
main_menu
