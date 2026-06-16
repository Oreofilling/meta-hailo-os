#!/bin/sh

exec 2>&1

DEVICE=$1

# Full offline fsck, then resize2fs -f (avoids spurious "e2fsck -f first" when already clean).
e2fsck -f -y "${DEVICE}"
e2fsck_exit=$?
if [ "${e2fsck_exit}" -ge 4 ]; then
	echo "e2fsck failed with exit code ${e2fsck_exit}"
	exit 1
fi

resize2fs -f "${DEVICE}"
resize2fs_exit=$?
if [ "${resize2fs_exit}" -ne 0 ]; then
	echo "resize2fs failed with exit code ${resize2fs_exit}"
	exit 2
fi
