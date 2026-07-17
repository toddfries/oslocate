#!/bin/ksh
# Offline regress for osmirror-lib (no network).
# Usage: ./regress/run.sh
set -e
HERE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$HERE"
. "$HERE/osmirror-lib"

fail=0
pass=0

assert_eq_file() {
	local name="$1" got="$2" exp="$3"
	if cmp -s "$got" "$exp"; then
		echo "PASS $name"
		pass=$((pass + 1))
	else
		echo "FAIL $name"
		echo "--- expected ---"
		cat "$exp"
		echo "--- got ---"
		cat "$got"
		echo "--- diff ---"
		diff -u "$exp" "$got" || true
		fail=$((fail + 1))
	fi
}

assert_eq_str() {
	local name="$1" got="$2" exp="$3"
	if [ "$got" = "$exp" ]; then
		echo "PASS $name"
		pass=$((pass + 1))
	else
		echo "FAIL $name got=[$got] exp=[$exp]"
		fail=$((fail + 1))
	fi
}

td=$(mktemp -d /tmp/osmirror-regress.XXXXXXXX)
trap 'rm -rf "$td"' 0 1 2 3 13 15

# --- pure transforms ---
osmirror_rclone_mungeforlocate "snapshots" \
	< regress/fixtures/rclone-lsl.txt > "$td/rclone-munge.txt"
assert_eq_file rclone_munge "$td/rclone-munge.txt" \
	regress/expected/rclone-munge-snapshots.txt

osmirror_rsync_mungeforlocate "patches" \
	< regress/fixtures/rsync-list.txt > "$td/rsync-munge.txt"
assert_eq_file rsync_munge "$td/rsync-munge.txt" \
	regress/expected/rsync-munge-patches.txt

osmirror_rclone_lsd_basenames \
	< regress/fixtures/rclone-lsd.txt > "$td/lsd.txt"
assert_eq_file rclone_lsd_basenames "$td/lsd.txt" \
	regress/expected/rclone-lsd-basenames.txt

osmirror_rsync_list_names \
	< regress/fixtures/rsync-list.txt > "$td/rsync-names.txt"
assert_eq_file rsync_list_names "$td/rsync-names.txt" \
	regress/expected/rsync-list-names.txt

assert_eq_str path_to_dname \
	"$(osmirror_path_to_dname 'NetBSD-archive/9.0')" \
	"NetBSD-archive_9.0"

# --- compress round-trip ---
echo "hello-osmirror" | osmirror_compress > "$td/t.xz"
got=$(xz -d < "$td/t.xz")
assert_eq_str compress_roundtrip "$got" "hello-osmirror"

# --- assemble_db with synthetic cache (needs locate.mklocatedb) ---
if [ -x /usr/libexec/locate.mklocatedb ]; then
	export sort="env LC_ALL=C sort"
	cachedir="$td/cache"
	mkdir -p "$cachedir"
	# mklocatedb wants enough unique bigrams — pad beyond tiny fixture
	{
		osmirror_rclone_mungeforlocate "7.6" < regress/fixtures/rclone-lsl.txt
		i=0
		while [ i -lt 200 ]; do
			printf "20240101%04d|%x|pad/file-%d.tgz\n" "$i" "$i" "$i"
			i=$((i + 1))
		done
	} | osmirror_compress > "$cachedir/7.6.xz"
	(
		cd "$td"
		dbname=test.database
		osmirror_assemble_db "$dbname"
		if [ -s "$dbname" ] && locate -d "$dbname" INDEX >/dev/null 2>&1; then
			echo PASS > "$td/assemble.status"
		elif [ -s "$dbname" ]; then
			echo PASS > "$td/assemble.status"
		else
			echo FAIL > "$td/assemble.status"
			ls -la > "$td/assemble.ls"
		fi
	)
	if [ "$(cat "$td/assemble.status")" = PASS ]; then
		echo "PASS assemble_db"
		pass=$((pass + 1))
	else
		echo "FAIL assemble_db"
		[ -f "$td/assemble.ls" ] && cat "$td/assemble.ls"
		fail=$((fail + 1))
	fi
else
	echo "SKIP assemble_db (no locate.mklocatedb)"
fi

echo
echo "Results: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
