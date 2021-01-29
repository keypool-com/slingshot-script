#!/bin/bash
CACHE_PATH=/cache
SIZE_4G=4*1024*1024*1024

if [ ! -f "$1" ]; then
    echo "Require input file."
    exit -1;
fi

if [ ! -d "$2" ]; then
    echo "Require output path."
    exit -1;
fi

if [ -z "$3" ]; then
    echo "Require prefix of download url."
    exit -1;
fi

input="$1"
filename=$(basename $1)
output="$2"
download_url="$3"
files=()

size=$(stat --printf="%s" $input)

if (( $size < $SIZE_4G )); then
    mkdir -p "$CACHE_PATH/iso_pending"
    mv -f $input "$CACHE_PATH/iso_pending"
    if (( $(du -sb "$CACHE_PATH/iso_pending"|cut -f1 ) >= $SIZE_4G )); then
        echo "Packing $CACHE_PATH/iso_pending"
        for f in "$CACHE_PATH/iso_pending"/*; do
            files+="$(basename $f) "
        done
        dir=$(mktemp -d -u -p $CACHE_PATH)
        mv "$CACHE_PATH/iso_pending" "$dir"
        tar cvf "$CACHE_PATH/$filename.tar" -C "$dir" .
        if [ $? != 0 ]; then
            echo "Failed to tar folder $dir."
            exit $?;
        fi
        input="$CACHE_PATH/$filename.tar"
        filename=$(basename $input)
        rm -rf $dir
    else
        exit 0;
    fi
else
    files+=$filename
fi

echo "Generating car file to $CACHE_PATH/$filename.car"
lotus client generate-car "$input" "$CACHE_PATH/$filename.car"

if [ $? != 0 ]; then
    echo "Failed to generate car file."
    exit $?
fi

echo "Generating piece info for $CACHE_PATH/$filename.car"
piece_info=$(lotus client commP "$CACHE_PATH/$filename.car")
if [ $? != 0 ]; then
    echo "Failed to generate piece info."
    exit $?
fi

cid=$(echo $piece_info|grep -oP 'CID:\s+\K\w+')
size=$(echo $piece_info|grep -oP 'Piece\ssize:\s+\K\d+')
if [ -z $cid ] || [ -z $size ]; then
    echo "Failed to capture piece info from $piece_info"
    exit -1
fi
echo "CID: $cid"
echo "Size: $size"

echo "Calculating md5 checksum for $CACHE_PATH/$filename.car"
md5=$(md5sum "$CACHE_PATH/$filename.car"| awk '{ print $1 }' )

if [ $? != 0 ]; then
    echo "Failed to calculate md5 checksum."
    exit $?
fi
echo "MD5: $md5"

echo "Moving $CACHE_PATH/$filename.car to $output"
mv -f "$CACHE_PATH/$filename.car" "$output"
if [ $? != 0 ]; then
    echo "Failed to move car file to output."
    exit $?
fi

rm -rf $input
echo "${files[*]},$download_url/$filename.car,$cid,$size,$md5" >> "$output/list.csv"
