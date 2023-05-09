#!/bin/sh
set -a
set -e

[ "$UTIL_SOURCED" = '1' ] && exit

RED='\x1b[31m'
ORANGE='\x1b[38;5;208m'
BLUE='\x1b[0;34m'
LIGHT_BLUE='\x1b[01;34m'
LIGHT_GREEN='\x1b[1;32m'
BOLD='\x1b[1m'
ITALIC='\x1b[3m'
UNDERLINE='\x1b[4m'
NC='\x1b[0m'

_process_msg() {
    printf "$*" | sed -e "s|<path>|$ORANGE|g" | sed -e "s|</path>|$NC$BOLD|g";
}

info() { printf "${BLUE}::${NC} ${BOLD}$(_process_msg "$(_process_msg "$*")")${NC}\n"; }

info_garr() { printf "${LIGHT_GREEN}${BOLD}==>${NC} ${BOLD}$(_process_msg "$*")${NC}\n"; }

info_barr() { printf "  ${BLUE}${BOLD}->${NC} ${BOLD}$(_process_msg "$*")${NC}\n"; }

warn() { printf "${ORANGE}::${NC} ${BOLD}$(_process_msg "$*")${NC}\n"; }

err() { printf "${RED}::${NC} ${BOLD}$(_process_msg "$*")${NC}\n"; }

confirm() { 
    set +a
    shell=0; y='y'; n='n'; ignore=0; barr=0

    args="$1"
    for _arg in $args; do
        [ "$_arg" = 'Y' ] && y='Y'
        [ "$_arg" = 'N' ] && n='N'
        [ "$_arg" = 'shell' ] && shell=1
        [ "$_arg" = 'ignore' ] && ignore=1
        [ "$_arg" = 'barr' ] && barr=1
    done
    shift

    while true; do
        if [ "$barr" -eq 1 ]; then
            printf "${BLUE} ->${NC}"
        else
            printf "${BLUE}::${NC}"
        fi
         printf " ${BOLD}$(_process_msg "$1")${NC} ${LIGHT_BLUE}${BOLD}(${y}/${n}"
        [ "$shell" -eq 1 ] && printf '/shell'
        printf ") >> ${NC}"
        
        if [ "$YOLO" -eq 1 ] && [ "$ignore" -eq 0 ]; then
            printf 'y\n'
            eval "$2"
            break
        else
	        read -r choice
	        case "$choice" in 
	            y|Y ) eval "$2"; break; ;;
	            n|N ) eval "$3"; break; ;;
                shell )
                    if [ "$shell" -eq 1 ]; then 
                        export PS1="${ORANGE}${BOLD}Confirm shell${NC} >> "
                        set +e; /bin/sh; set -e
                        unset PS1
                    else continue; fi
                    ;;
                '' )
                    if [ "$y" = 'Y' ]; then eval "$2"; break; fi
                    if [ "$n" = 'N' ]; then eval "$3"; break; fi
                    continue
                    ;;
	            * ) continue; ;;
	        esac
        fi
    done
    set -a
}

chown_user() { for path in "$@"; do chown -R $USER1:$USER_GROUP "$path"; done; }

chown_root() { for path in "$@"; do chown -R root:root "$path"; done; }


slient() { "$@" > /dev/null; }

slient_err() { "$@" > /dev/null 2>&1; }

ignore_err() { "$@" || :; }

check_is_root() {
    if [ "$(whoami)" != 'root' ]; then
        err 'This script needs to be run as root.'
        exit 1
    fi
}

check_isnt_root() {
    if [ "$(whoami)" = 'root' ]; then
        err 'This script cant be run as root.'
        exit 1
    fi
}

handle_args() {
    set +a
    inshort="h=_help,$1"
    inlong="help=_help,$2"
    short="$(echo "$inshort" | tr ',' '\n' | awk -F'=' '{print $1}' | tr '\n' ',')"; 
    long="$(echo "$inlong" | tr ',' '\n' | awk -F'=' '{print $1}' | tr '\n' ',')"; 
    
    
    set +e
    if ! opts=$(getopt --alternative --name install --options "h $short" --longoptions "$long" -- "$@"); then
        _help
        exit 1
    fi
        
    IFS=","
    eval set -- "$opts"
    while true; do
        for arg in $inshort; do
            name="-$(echo $arg | awk -F'=' '{print $1}')"
            [ "$(echo "$name" | tail -c -2)" = ':' ] && name="$(echo "$name" | head -c -2)"  
            
            if [ "$1" = "$name" ]; then
               eval "$(echo "$arg" | awk '{print substr($0, index($0, "=")+1)}')"
               shift
               continue 2
            fi
        done
        for arg in $inlong; do
            name="--$(echo "$arg" | awk -F'=' '{print $1}')"
            [ "$(echo "$name" | tail -c -2)" = ':' ] && name="$(echo "$name" | head -c -2)"  

            if [ "$1" = "$name" ]; then
                eval "$(echo "$arg" | awk '{print substr($0, index($0, "=")+1)}')"
                shift
                [ "$(echo "$name" | grep ':')" != '' ] && shift
                continue 2
            fi
        done
        if [ "$1" = '--' ]; then
            shift
            break
        fi

        err "Unexpected option: $1"
        exit 1

    done
    unset IFS
    set -a
}


if [ -z "$USER1" ]; then
    user="$(whoami)"
    if [ "$user" = 'root' ]; then
        err "Enviroment variable USER1 is not set. Cannot continue."
        exit 1
    fi
    USER1="$user"
    unset user
fi

USER_GROUP="$(id -gn $USER1)"
USER_HOME="/home/$USER1/home"
REAL_USER_HOME="/home/$USER1"

[ -z "$YOLO" ] && YOLO=0

mkdir -p "$USER_HOME"
mkdir -p "$DOTDIR"/tmp

UTIL_SOURCED=1
