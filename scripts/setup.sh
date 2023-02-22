#!/usr/bin/env bash
#
# this is service bootstrap logic to be called from container entrypoint.
#
# - sets up our user (abc) id & gid;
# - initialises crontab;
# - configures msmtprc for mail notifications;

readonly SELF="${0##*/}"
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"  # location of this script

readonly REGULAR_USER=abc  # needs to be kept in-sync with value in Dockerfile!
readonly CRONFILE_TEMPLATE='/cron.template'
readonly CRON_TARGET="/etc/crontabs/$REGULAR_USER"  # note filename needs to match user's!
readonly DEFAULT_CRON_PATTERN='*/5 * * * *'

JOB_ID="setup-$$"


check_dependencies() {
    local i

    for i in curl bc tr sed grep find file flock groupmod usermod ping rclone unzip unrar; do
        command -v "$i" >/dev/null || fail "[$i] not installed"
    done
}


setup_users() {
    # note we default user:group to nobody:users
    PUID=${PUID:-99}
    PGID=${PGID:-100}

    is_digit "$PUID" || fail "PUID needs to be a digit, but is [$PUID]"
    is_digit "$PGID" || fail "PGID needs to be a digit, but is [$PGID]"

    groupmod -o -g "$PGID" "$REGULAR_USER" || fail "groupmod exited w/ $?"
    usermod -o -u "$PUID" "$REGULAR_USER" || fail "usermod exited w/ $?"
}


setup_cron() {
    if [[ -f "$CONF_ROOT/crontab" ]]; then
        cp -- "$CONF_ROOT/crontab" "$CRON_TARGET" || fail "copying user-provided crontab failed"
    else
        # copy fresh template...
        cp -- "$CRONFILE_TEMPLATE" "$CRON_TARGET" || fail "copying cron template failed"

        # add cron entry:
        printf '%s  sync.sh\n' "${CRON_PATTERN:-"$DEFAULT_CRON_PATTERN"}" >> "$CRON_TARGET"
    fi
}


setup_logrotate() {
    local opt rotate interval size name pattern rotate_confdir target_conf OPTIND

    while getopts 'r:i:s:n:p:' opt; do
        case "$opt" in
            r) rotate="$OPTARG"
                ;;
            i) interval="$OPTARG"
                ;;
            s) size="$OPTARG"
                ;;
            n) name="$OPTARG"
                ;;
            p) pattern="$OPTARG"
                ;;
            *) fail "$FUNCNAME called with unsupported flag(s)"
                ;;
        esac
    done
    shift "$((OPTIND-1))"

    [[ -z "$rotate" ]] && rotate=3
    [[ -z "$interval" ]] && interval=weekly
    [[ -z "$size" ]] && size=5M
    [[ -z "$name" ]] && name=common-config
    [[ -z "$pattern" ]] && pattern="$LOG_ROOT/*.log"


    rotate_confdir='/etc/logrotate.d'
    target_conf="$rotate_confdir/$name"

    [[ -d "$rotate_confdir" ]] || fail "[$rotate_confdir] is not a dir - is logrotate installed?"

    if [[ -f "$LOGROTATE_CONF" && -s "$LOGROTATE_CONF" ]]; then
        cat -- "$LOGROTATE_CONF" > "$target_conf"
    else
        cat > "$target_conf" <<EOF
$pattern {
                   rotate $rotate
                   $interval
                   size $size
                   copytruncate
                   compress
                   missingok
                   notifempty
}
EOF
    fi
}


# ================
# Entry
# ================
#NO_SEND_MAIL=true  # stop sending mails during startup/setup; allow other notifications
source /common.sh || { echo -e "    ERROR: failed to import /common.sh"; exit 1; }

check_dependencies
setup_users
validate_config_common  # make sure this comes after setup_users(), so PUID/PGID env vars are set
setup_cron
#setup_msmtp
setup_logrotate
#unset NO_SEND_MAIL

exit 0

