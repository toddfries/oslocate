# NetBSD mirror profile for osmirror-driver (sourced).

osmirror_dbname=allnbsd.database
osmirror_apichangedate=1758567522
osmirror_release_rmt=${NB_RELEASE_RMT:-nb-https}
osmirror_pkg_rmt=${NB_PKG_RMT:-nb-pkg-https}

osmirror_static_release_re='^NetBSD-[0-9][0-9]*\.[0-9]'

set -A osmirror_hot_paths -- \
	arch NetBSD-current NetBSD-daily images install-images \
	iso misc packages releng security torrent

osmirror_hot_path_re='^NetBSD-release'
osmirror_archive_prefix=NetBSD-archive

osmirror_profile_walk() {
	local d dname path p2 ptmp

	# Release trees (static once cached)
	for d in $(osmirror_rclone_lsrmt "$osmirror_release_rmt" | egrep "$osmirror_static_release_re")
	do
		cksys
		d=${d%/}
		dname=$(osmirror_path_to_dname "$d")
		if ! [ -f "$cachedir/${dname}.xz" ]; then
			osmirror_rclone_cache_dir "$osmirror_release_rmt" "$d" || exit 1
		fi
	done

	# Package sets: two-level walk
	for d in $(osmirror_rclone_lsrmt "$osmirror_pkg_rmt")
	do
		cksys
		d=${d%/}
		echo "pkg-https $d>"
		for p2 in $(osmirror_rclone_lsrmt "$osmirror_pkg_rmt" "$d")
		do
			cksys
			p2=${p2%/}
			ptmp="$d/$p2"
			echo "pkg-https $ptmp>"
			dname=$(osmirror_path_to_dname "$ptmp")
			if ! [ -f "$cachedir/${dname}.xz" ]; then
				osmirror_rclone_cache_dir "$osmirror_pkg_rmt" "$ptmp" || exit 1
			fi
		done
	done

	# Volatile top-level dirs
	for path in "${osmirror_hot_paths[@]}"
	do
		cksys
		osmirror_rclone_cache_dir "$osmirror_release_rmt" "$path" || exit 1
	done
	for path in $(osmirror_rclone_lsrmt "$osmirror_release_rmt" | egrep "$osmirror_hot_path_re")
	do
		cksys
		path=${path%/}
		osmirror_rclone_cache_dir "$osmirror_release_rmt" "$path" || exit 1
	done

	# Historic archive
	for d in $(osmirror_rclone_lsrmt "$osmirror_release_rmt" "$osmirror_archive_prefix")
	do
		cksys
		d=${d%/}
		dname=$(osmirror_path_to_dname "${osmirror_archive_prefix}_${d}")
		if ! [ -f "$cachedir/${dname}.xz" ]; then
			osmirror_rclone_cache_dir "$osmirror_release_rmt" \
				"${osmirror_archive_prefix}/$d" || exit 1
		fi
	done
}
