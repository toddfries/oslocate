# OpenBSD mirror profile for osmirror-driver (sourced).

osmirror_dbname=allobsd.database
osmirror_apichangedate=1758567522
osmirror_rclone_rmt=${OB_RCLONE_RMT:-ob-http}
osmirror_rsync_probe=${OB_RSYNC_PROBE:-snapshots/amd64/index.txt}

# Prefer last listed if multiple answer (same order as historic addrpath).
set -A osmirror_rsync_mirrors -- \
	"rsync://mirror.esc7.net/openbsd" \
	"rsync://ftp.spline.de/OpenBSD" \
	"rsync://ftp.hostserver.de/OpenBSD" \
	"rsync://ftp.usa.openbsd.org/ftp" \
	"rsync://mirror.planetunix.net/OpenBSD/" \
	"rsync://mirror.leaseweb.com/openbsd/"

# Static release roots (rclone once): egrep on basenames
osmirror_static_release_re='^[0-9].[0-9]'

# Hot paths (rsync every -B)
set -A osmirror_hot_paths -- \
	ftplist timestamp Changelogs OpenSSH/portable patches snapshots

osmirror_profile_walk() {
	local d dname path

	osmirror_pick_rsync_obstyle "$osmirror_rsync_probe" "${osmirror_rsync_mirrors[@]}" || true

	# should be static, rm to refresh
	for d in $(osmirror_rclone_lsrmt "$osmirror_rclone_rmt" | egrep "$osmirror_static_release_re")
	do
		cksys
		d=${d%*/}
		dname=$(osmirror_path_to_dname "$d")
		if ! [ -f "$cachedir/${dname}.xz" ]; then
			osmirror_rclone_cache_dir "$osmirror_rclone_rmt" "$d" || exit 1
		fi
	done

	# update each time
	for path in "${osmirror_hot_paths[@]}"
	do
		cksys
		osmirror_rsync_cache_dir "$path" || exit 1
	done
}
