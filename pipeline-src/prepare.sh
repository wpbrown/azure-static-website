#!/bin/bash

hugoUrl='https://github.com/gohugoio/hugo/releases/download/v0.46/hugo_0.46_Linux-64bit.deb'
hugoCheck='de865b7965c3eb0e958035478074f0f29ebfc8b28ddba2d671318404d839cb5d'
rcloneUrl='https://downloads.rclone.org/v1.42/rclone-v1.42-linux-amd64.deb'
rcloneCheck='acc72d39be7110a8c5e54fb18a78a7e7bd86316754056bd0a0e92df59d51b796'

download() {
    curl -L -o "$1" "$2"
    echo "$3 $1" | sha256sum -c -
}

download 'hugo.deb' "$hugoUrl" "$hugoCheck" || exit 1
sudo dpkg -i 'hugo.deb' || exit 2
download 'rclone.deb' "$rcloneUrl" "$rcloneCheck" || exit 3
sudo dpkg -i 'rclone.deb' || exit 4
