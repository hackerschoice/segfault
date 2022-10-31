#! /bin/bash

cd /dev/pts
for x in *; do
	[[ $x == ptmx ]] && continue
	echo -e "$*" >"/dev/pts/$x"
done
