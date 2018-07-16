#!/bin/sh

#
# very simple cli notes management
#

prog_name=$(basename $0)
notes_dir=~/Documents/notes/    # script requires folder to exist
editor=${EDITOR:-nano}          # default to nano

function help {
    echo "Usage: $prog_name [-a filename] [-r filename] [-s pattern] [-l]"
	echo
	echo "Options"
    echo "    -a, --add <filename>          Open note 'filename' in specified editor"
    echo "    -r, --remove <filename>       Remove note 'filename'"
    echo "    -s, --search <pattern>        Search notes for pattern"
	echo "    -l, --list                    List all notes"
	echo
}

function add {
    $editor $notes_dir"$*"
}

function remove {
    rm $notes_dir"$*"
}

function list {
    ls -c $notes_dir | grep "$*"
}

function search {
    #grep -rni "$notes_dir" -e "$*" --color=always # more verbose variant
    grep -rnil "$notes_dir" -e "$*" | xargs -L 1 basename  # -l required if using basename
    # -l to only show filename then output the file basename instead of whole path
    # -w for whole words in case too many results show up over time
}

subcommand=$1
case $subcommand in
	"" | "-h" | "--help")	help
							;;
	"-a" | "--add") 		shift
							add $@
							;;
    "-r" | "--remove") 		shift
							remove $@
							;;
	"-s" | "--search")    	shift
                            search $@
							;;
    "-l" | "--list")    	list
							;;
	*)						echo "Error: '$subcommand' is not a known command." >&2
							echo "       Run '$prog_name --help' for a list of known commands." >&2
							exit 1
							;;
esac