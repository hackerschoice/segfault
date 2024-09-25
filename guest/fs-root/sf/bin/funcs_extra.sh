#! /bin/bash

addfileextension() {
    local fn="${1:?}"
    local r

    r=$(file -b --extension "$fn")
    r="${r%%\/*}"

    [[ "$r" == "???" ]] && {
        r=$(file -b "$fn")
        if [[ "$r" == *Zip* ]]; then
            r="zip"
        elif [[ "$r" == *MIME* ]]; then
            r="mime"
        elif [[ "$r" == *"very long lines"* ]]; then
            r="csv"
        elif [[ "$r" == *"OOXML"* ]]; then
            r="docx"
        elif [[ "$r" == *"Office Word"* ]]; then
            r="doc"
        elif [[ "$r" == *"Excel"* ]]; then
            r="xlsx"
        elif [[ "$r" == *"MP4"* ]]; then
            r="mp4"
        elif [[ "$r" == *"HTML"* ]]; then
            r="html"
        elif [[ "$r" == *"HEIF"* ]]; then
            r="heif"
        elif [[ "$r" == *"EMF"* ]]; then
            r="emf"
        elif [[ "$r" == *" text"* ]]; then
            r="txt"
        else
            unset r
        fi
    }
    [[ -z $r ]] && { echo >&2 "Unknown file type: $fn"; return; }

    [[ "$fn" =~ .*$r$ ]] && return
    mv "$fn" "$fn.$r"
}

crt() {
    [ $# -ne 1 ] && { echo >&2 "crt <domain-name>"; return 255; }
    curl -s "https://crt.sh/?q=${1:?}&output=json" --compressed | jq -r '.[].common_name,.[].name_value' | anew | sed 's/^\*\.//g' | tr '[:upper:]' '[:lower:]'
}
