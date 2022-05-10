#! /bin/bash

RAWDIR="/encfs/raw/user-${LID}"
SECDIR="/encfs/sec/user-${LID}"
mkdir -p "${RAWDIR}" "${SECDIR}" 2>/dev/null
if [[ -n $MARKFILE ]]; then
	if [[ -n $CHECKFILE ]]; then
		n=0
		while [[ -f "${SECDIR}/${MARKFILE}" ]]; do
			[[ $n -gt 0 ]] && sleep 2 || sleep 0.1
			n=$((n+1))
			[[ $n -gt 5 ]] && exit 253 # "Could not create /sec..."
		done
		# echo "encrypted" >/sec/.encrypted
		exit 0 # /sec created
	fi
	touch "${SECDIR}/${MARKFILE}" || exit 255
	echo "Failed to set up encrypted drive. DO NOT USE THIS DIRECTORY" >"${SECDIR}/${MARKFILE}"
	exit 0
fi

encfs --standard -o nonempty -o allow_other --extpass="echo \"${LENCFS_PASS}\"" "${RAWDIR}" "${SECDIR}"

# Unmount when no instance is running anymore.
sleep 5
while :; do
	docker container inspect "lg-${LID}" -f '{{.State.Status}}' || break
	sleep 10
done

echo "Unmounting lg-${LID} [${SECDIR}]"
fusermount -zuq /encfs/sec || echo "fusermount: Error ($?)"
echo "DONE"
