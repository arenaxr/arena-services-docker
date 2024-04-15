# text formatting/colors

BOLD=$(tput bold)
NORMAL=$(tput sgr0)

BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)

ERROR=$RED
HIGHLIGHT=$CYAN
WARNING=$MAGENTA
MUTED=$POWDER_BLUE

# portable timeout function (requires perl)
function timeout() { perl -e 'alarm shift; exec @ARGV' "$@"; }

# output error messages
echoerr() { printf "${ERROR}ERROR: %s${NORMAL}\n" "$*" >&2; }

# output error message and exit
exiterr() { printf "${ERROR}ERROR: %s${NORMAL}\n" "$*" >&2; exit 1; }

# output colored messages
echocolor() { 
    color=$1
    shift
    printf "${color}%s${NORMAL}\n" "$*"; 
}

# check flag and read user input
readprompt() {
    [ ! "$ALWAYS_YES" == "true" ] && echo "" && read -p "$1" -r || REPLY="y"
}
