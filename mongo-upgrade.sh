#!/bin/bash
# mongo-upgrade.sh — walk the MongoDB data directory up through major versions, one step at a time.
#
# MongoDB only supports upgrading one major version at a time (4.2 → 4.4 → 5.0 → 6.0 → 7.0 → 8.0),
# and each step requires the data's featureCompatibilityVersion (FCV) to already be at the previous
# major. This script automates that walk using throwaway `docker run` containers against ./data/mongodb,
# so it works the same for localdev, staging, prod and demo. Nothing else in the stack is touched.
#
# usage: ./mongo-upgrade.sh [-t TARGET] [-f FROM] [-d DATA_DIR] [-b BACKUP_DIR] [-n] [-y] [--no-backup] [--as-root]
#   -t TARGET    major version to end at (e.g. 8 or 8.0). Default: MONGO_VERSION from ./VERSION
#   -f FROM      major version the data was last run with. Default: detected from the existing
#                mongodb container's image tag (stack may be stopped; the container must still exist)
#   -d DATA_DIR  MongoDB data dir. Default: ./data/mongodb
#   -b BACKUP_DIR  where to write the pre-upgrade mongodump archive. Default: ./data/backup/mongo-upgrade
#   -n           dry run: print the plan and exit
#   -y           don't ask for confirmation (and stop a running mongodb container if needed)
#   --no-backup  skip the mongodump (not recommended)
#   --as-root    run the temporary mongod as root instead of the image's mongodb user.
#                Default ON for macOS Docker Desktop, where VirtioFS bind mounts present files as
#                root-owned and mongod fails with "Operation not permitted" (EPERM on O_NOATIME).
#
# Typical use, after `git pull` changed MONGO_VERSION in VERSION (or the pin in a compose file):
#   ./prod.sh down          # or staging.sh / localdev.sh / demo.sh
#   ./mongo-upgrade.sh      # walks FROM → TARGET, one major at a time, with a backup first
#   ./prod.sh up -d
#
# You can also run one step at a time: ./mongo-upgrade.sh -t 6 ; ./mongo-upgrade.sh -f 6 -t 7 ; ...
set -euo pipefail

SUPPORTED=(4.2 4.4 5.0 6.0 7.0 8.0)   # in upgrade order; extend at the end when MongoDB releases a new major
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DATA_DIR="$REPO/data/mongodb"
BACKUP_DIR="$REPO/data/backup/mongo-upgrade"
TARGET=""; FROM=""; DRY_RUN=0; YES=0; BACKUP=1; AS_ROOT=""
READY_TIMEOUT=${MONGO_UPGRADE_READY_TIMEOUT:-300}   # seconds to wait for each mongod to accept connections
CNAME="arena-mongo-upgrade-$$"

usage() { sed -n '2,/^set -euo/p' "$0" | grep -v '^set ' | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
die() { >&2 echo "ERROR: $*"; exit 1; }
log() { echo "==> $*"; }

while [ $# -gt 0 ]; do
    case "$1" in
        -t) TARGET="$2"; shift 2 ;;
        -f) FROM="$2"; shift 2 ;;
        -d) DATA_DIR="$2"; shift 2 ;;
        -b) BACKUP_DIR="$2"; shift 2 ;;
        -n) DRY_RUN=1; shift ;;
        -y) YES=1; shift ;;
        --no-backup) BACKUP=0; shift ;;
        --as-root) AS_ROOT=1; shift ;;
        -h|--help) usage 0 ;;
        *) >&2 echo "Unknown argument: $1"; usage 1 ;;
    esac
done

command -v docker >/dev/null || die "docker not found"
[ -d "$DATA_DIR" ] || die "data dir not found: $DATA_DIR"
DATA_DIR=$(cd -- "$DATA_DIR" && pwd)
[ -f "$DATA_DIR/WiredTiger" ] || die "$DATA_DIR does not look like a MongoDB (WiredTiger) data dir"
[ -n "$AS_ROOT" ] || { [ "$(uname -s)" = "Darwin" ] && AS_ROOT=1 || AS_ROOT=0; }

# "8", "8.0", "8.0.4", "v8" → "8.0"; refuse "latest" and the ambiguous "4"
normalize() {
    local v=${1#v}
    case "$v" in
        latest|"") die "version '$1' is not a pinned major version; pin MONGO_VERSION (e.g. 8) and retry" ;;
        4) die "'4' is ambiguous (4.2 or 4.4); pass -f/-t with the minor version" ;;
    esac
    local major=${v%%.*} minor
    if [[ "$v" == *.* ]]; then minor=${v#*.}; minor=${minor%%.*}; else minor=0; fi
    echo "$major.$minor"
}
index_of() { local i; for i in "${!SUPPORTED[@]}"; do [ "${SUPPORTED[$i]}" = "$1" ] && { echo "$i"; return; }; done; return 1; }

# Containers (running or stopped) that bind-mount DATA_DIR: "<id> <running> <image>"
containers_on_data_dir() {
    local ids; ids=$(docker ps -aq) || return 0
    [ -n "$ids" ] || return 0
    # shellcheck disable=SC2086
    docker inspect --format '{{.Id}} {{.State.Running}} {{.Config.Image}}{{range .Mounts}} {{.Source}}{{end}}' $ids 2>/dev/null \
        | awk -v d="$DATA_DIR" '{ for (i=4;i<=NF;i++) if ($i==d) { print $1, $2, $3; break } }'
}

# --- work out FROM and TARGET -------------------------------------------------------------------
if [ -z "$TARGET" ]; then
    TARGET=$(grep -E '^MONGO_VERSION=' "$REPO/VERSION" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]"' || true)
    [ -n "$TARGET" ] || die "no -t given and no MONGO_VERSION in $REPO/VERSION"
fi
TARGET=$(normalize "$TARGET")

EXISTING=$(containers_on_data_dir)
if [ -z "$FROM" ]; then
    img=$(echo "$EXISTING" | awk '{print $3}' | sort -u)
    case "$(echo "$img" | wc -l | tr -d ' ')" in
        0) die "cannot detect the current version (no container mounts $DATA_DIR); pass -f <version the data was last run with>" ;;
        1) ;;
        *) die "several containers with different images mount $DATA_DIR ($(echo "$img" | tr '\n' ' ')); pass -f explicitly" ;;
    esac
    case "$img" in
        mongo:*) FROM=$(normalize "${img#mongo:}") ;;
        *) die "cannot infer a version from image '$img'; pass -f explicitly" ;;
    esac
    log "detected current version $FROM from container image $img"
else
    FROM=$(normalize "$FROM")
fi

fi_=$(index_of "$FROM") || die "unsupported FROM version $FROM (known: ${SUPPORTED[*]})"
ti_=$(index_of "$TARGET") || die "unsupported TARGET version $TARGET (known: ${SUPPORTED[*]}); add it to SUPPORTED if MongoDB released a new major"
[ "$ti_" -ge "$fi_" ] || die "downgrades are not supported ($FROM → $TARGET); restore from a backup taken with $TARGET instead"

PATH_VERSIONS=("${SUPPORTED[@]:$fi_:$((ti_ - fi_ + 1))}")

echo
echo "MongoDB upgrade plan"
echo "  data dir : $DATA_DIR"
echo "  from     : $FROM  (FCV will be verified/set to $FROM first if needed)"
echo "  to       : $TARGET"
echo "  steps    : ${PATH_VERSIONS[*]}"
echo "  backup   : $([ $BACKUP = 1 ] && echo "$BACKUP_DIR (mongodump --gzip archive, taken with mongo:$FROM)" || echo "SKIPPED")"
echo "  run as   : $([ "$AS_ROOT" = 1 ] && echo root || echo mongodb)"
if [ "$fi_" = "$ti_" ]; then echo "  note     : already on $TARGET; this run only verifies/sets the FCV"; fi
echo
[ $DRY_RUN = 1 ] && exit 0

running=$(echo "$EXISTING" | awk '$2=="true"{print $1}')
if [ -n "$running" ]; then
    echo "A container is running against $DATA_DIR ($(echo "$running" | cut -c1-12 | tr '\n' ' ')). It must be stopped first."
    if [ $YES = 0 ]; then read -r -p "Stop it now? (y/N) " r; [[ "$r" =~ ^[Yy]$ ]] || die "aborted; run ./<env>.sh down and retry"; fi
    # shellcheck disable=SC2086
    docker stop $running >/dev/null
fi
if [ $YES = 0 ]; then read -r -p "Proceed? (y/N) " r; [[ "$r" =~ ^[Yy]$ ]] || die "aborted"; fi

# --- helpers to run a throwaway mongod ------------------------------------------------------------
cleanup() { docker rm -f "$CNAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

SHELL_BIN=""
mongo_eval() { docker exec "$CNAME" "$SHELL_BIN" --quiet --eval "$1"; }

start_mongod() {  # $1 = version
    local v=$1 entry=()
    [ "$AS_ROOT" = 1 ] && entry=(--entrypoint mongod)
    docker pull -q "mongo:$v" >/dev/null
    docker run -d --name "$CNAME" -v "$DATA_DIR:/data/db" -v "$BACKUP_DIR:/backup-upgrade" \
        -e GLIBC_TUNABLES=glibc.pthread.rseq=1 "${entry[@]}" "mongo:$v" >/dev/null
    SHELL_BIN=$(docker exec "$CNAME" sh -c 'command -v mongosh || command -v mongo')
    local t=0
    until [ "$(mongo_eval 'db.adminCommand({ping:1}).ok' 2>/dev/null)" = "1" ]; do
        if [ "$(docker inspect -f '{{.State.Running}}' "$CNAME")" != "true" ]; then
            >&2 echo "mongo:$v exited while starting on this data dir. Last log lines:"
            docker logs --tail 15 "$CNAME" >&2
            die "mongo:$v failed to start. If the data is older than $(( ${v%%.*} - 1 )).x, retry with -f <older version>."
        fi
        t=$((t + 2)); [ $t -le "$READY_TIMEOUT" ] || die "mongo:$v did not become ready in ${READY_TIMEOUT}s"
        sleep 2
    done
}
stop_mongod() { docker stop -t 120 "$CNAME" >/dev/null; docker rm "$CNAME" >/dev/null; }
get_fcv() { mongo_eval 'print(db.adminCommand({getParameter:1,featureCompatibilityVersion:1}).featureCompatibilityVersion.version)'; }
set_fcv() {  # $1 = version; 7.0+ requires confirm:true, older servers reject the unknown field
    local v=$1 out
    out=$(mongo_eval "JSON.stringify(db.adminCommand({setFeatureCompatibilityVersion:'$v', confirm:true}))")
    if echo "$out" | grep -q "unknown field"; then
        out=$(mongo_eval "JSON.stringify(db.adminCommand({setFeatureCompatibilityVersion:'$v'}))")
    fi
    echo "$out" | grep -q '"ok":1' || die "setFeatureCompatibilityVersion $v failed: $out"
}

# --- walk the versions -------------------------------------------------------------------------------
mkdir -p "$BACKUP_DIR"
TS=$(date -u +%Y%m%dT%H%M%SZ)
for v in "${PATH_VERSIONS[@]}"; do
    log "starting mongo:$v on $DATA_DIR"
    start_mongod "$v"
    if [ "$v" = "$FROM" ] && [ $BACKUP = 1 ]; then
        archive="mongo-upgrade-${FROM}-${TS}.archive.gz"
        log "backing up all databases to $BACKUP_DIR/$archive"
        docker exec "$CNAME" mongodump --quiet --gzip --archive="/backup-upgrade/$archive"
        echo "    restore with: docker run --rm -v $BACKUP_DIR:/b -v <empty-data-dir>:/data/db mongo:$FROM bash -c 'mongod --fork --logpath /tmp/m.log && mongorestore --gzip --archive=/b/$archive'"
    fi
    fcv=$(get_fcv)
    if [ "$fcv" = "$v" ]; then
        log "mongo:$v is up, FCV already $fcv"
    else
        log "mongo:$v is up with FCV $fcv; setting FCV to $v"
        set_fcv "$v"
        fcv=$(get_fcv); [ "$fcv" = "$v" ] || die "FCV is $fcv after setFeatureCompatibilityVersion $v"
        log "FCV is now $fcv"
    fi
    stop_mongod
done

echo
log "done: $DATA_DIR is on MongoDB $TARGET with FCV $TARGET"
echo "Next: make sure the pin matches (MONGO_VERSION=$TARGET in VERSION for prod/demo; image tag in the staging/localdev compose file), then bring the stack up."
