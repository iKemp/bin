#!/bin/bash

#
# very early work in progress
#
# custom fish completion for openshift origin cli 
# source oc bash completion and transform into fish completion
#
# refs
# https://fishshell.com/docs/current/index.html#completion
# https://fishshell.com/docs/current/commands.html#complete
# /usr/share/fish/completions/git.fish
#

echo create oc fish completion

# read in bash completion and write to file
oc completion bash > yolo.tmp

# source bash completion file to execute commands later
source ./yolo.tmp

# remove tmp file
rm yolo.tmp

# entrypoint
_oc
#echo ${commands[*]}
#echo ${commands[@]}    # geht beides

outputfile_name=outputfile.tmp

# write headline
echo "# generated via $PWD/`basename "$0"`" >> outputfile_name

for i in ${commands[@]}; do
    completion="complete -c oc -a $i"
    echo $completion >> outputfile_name

    # TODO complete for all subcommands
done

# copy outputfile to fish completion folder
cp outputfile_name ~/.config/fish/completions/oc.fish
rm outputfile_name

