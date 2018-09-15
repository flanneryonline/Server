#!/usr/bin/env bash

. ${SERVER_INSTALL:-~/server}/install/include
. ${SERVER_INSTALL:-~/server}/install/environment

initialize_services() {
    [ x$root = x ] && local chroot_eval=

    for compose in $(ls -l $root/etc/docker/compose | grep "^d" | tr -s ' ' | cut -d' ' -f 9-); do
        eval "$chroot_eval systemctl enable docker-compose@$compose"
        errorcheck && echoerr "error initializing $compose" && return 1
    done
    return 0
}

long_running_stuff() {

    #run these async
    rsync_movies &
    movies_pid=$!
    rsync_shows &
    shows_pid=$!
    rsync_configs &
    configs_pid=$!
    rsync_data &
    data_pid=$!
    rsync_other &
    other_pid=$!

    wait $configs_pid
    errorcheck && echoerr "error in rsync_configs." && kill_others && return 1
    echo "rsync_configs complete."

    wait $other_pid
    errorcheck && echoerr "error in rsync_other." && kill_others && return 1
    echo "rsync_other complete."

    wait $data_pid
    errorcheck && echoerr "error in rsync_data." && kill_others && return 1
    echo "rsync_data complete."

    wait $shows_pid
    errorcheck && echoerr "error in rsync_shows." && kill_others && return 1
    echo "rsync_shows complete."

    wait $movies_pid
    errorcheck && echoerr "error in rsync_movies." && return 1
    echo "rsync_movies complete."

    return 0
}

kill_others() {
    kill -0 $configs_pid && kill_children $configs_pid
    kill -0 $other_pid && kill_children $other_pid
    kill -0 $data_pid && kill_children $data_pid
    kill -0 $shows_pid && kill_children $shows_pid
    kill -0 $movies_pid && kill_children $movies_pid

    return 0
}

kill_children() {
    for child in $(ps -o pid,ppid -ax | awk "{ if ( \$2 == $1 ) { print \$1 }}")
    do
        kill_children $child
    done
    kill $1
    return 0
}

rsync_configs() {

    #rsync -azqHAX -e ssh root@$BACKUP_ADDRESS:/$BACKUP_FOLDER/ $STORAGE_CONFIG_DIR
    #errorcheck && echoerr "error while syncing configs." && return 1

    return 0
}

rsync_shows() {

    #rsync -azqHAX -e ssh root@$BACKUP_ADDRESS:/$BACKUP_FOLDER/media/ $STORAGE_MEDIA_DIR/shows
    #errorcheck && echoerr "error while syncing shows." && return 1

    return 0
}

rsync_data() {

    #rsync -azqHAX -e ssh root@$BACKUP_ADDRESS:/$BACKUP_FOLDER/ $STORAGE_MEDIA_DIR/shares
    #errorcheck && echoerr "error while syncing shares." && return 1

    return 0
}

rsync_movies() {

    #rsync -azqHAX -e ssh root@$BACKUP_ADDRESS:/$BACKUP_FOLDER/media/ $STORAGE_MEDIA_DIR/movies
    #errorcheck && echoerr "error while syncing movies." && return 1

    return 0
}

rsync_other() {

    #rsync -azqHAX -e ssh root@$BACKUP_ADDRESS:/$BACKUP_FOLDER/media/ $STORAGE_MEDIA_DIR/other
    #errorcheck && echoerr "error while syncing other media." && return 1

    return 0
}

long_running_stuff
errorcheck && exit 1
initialize_services
errorcheck && exit 1

exit 0
