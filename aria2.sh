#!/bin/bash

process_file() {
    input=$1;
    filename=$(basename $input)
    extension="${filename##*.}"

    case $input in
        *.iso | *.img)
            /root/scripts/iso.sh "$input" "/data/cars/isos/" "https://cars.keypool.tech/isos"
        ;;
        *.jigdo)
            jigdo-lite --noask $input
            if [ $? == 0 ]; then
                rm -f "$(dirname $input)/$filename"
                rm -f "$(dirname $input)/${filename%.*}.template"
                process_file "$(pwd)/${filename%.*}.iso"
            fi
        ;;
        *.xz)
            echo "Unpacking $input"
            unxz $input
            if [ $? == 0 ]; then
                process_file "$(dirname $input)/${filename%.*}"
            fi
        ;;
        *)
            echo "Unsupported extension $extension"
            exit -1;
        ;;
    esac
}

process_file $3;
