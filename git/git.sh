function git(){
    if [[ "$1" == "add" ]]; then
        shift
        if [ -z "$1" ]; then
            selected_files_relative=$(command git status --porcelain | awk '{print $2}' | \
                                      fzf --multi --prompt="Add file to stage: " \
                                          --height=40% --layout=reverse --border)
            if [ -n "$selected_files_relative" ]; then
                repo_root=$(command git rev-parse --show-toplevel)

                if [ -z "$repo_root" ]; then
                    echo "Error: Not in a Git repository." >&2
                    command git add "$@"
                    return 1
                fi
                readarray -t selected_files_relative_array <<< "$selected_files_relative"
                local selected_files_absolute_array=()
                for relative_path in "${selected_files_relative_array[@]}"; do
                    absolute_path="$repo_root/$relative_path"
                    selected_files_absolute_array+=("$absolute_path")
                done
                if command git add "${selected_files_absolute_array[@]}"; then
                    echo "Files added to stage:"
                    for file in "${selected_files_absolute_array[@]}"; do
                        echo "- $file"
                    done
                else
                    echo "Error adding selected files to the staging area." >&2
                fi         
            fi
        elif [[ "$1" == "." ]]; then
            command git add .
        elif [ "$1" == "all" ]; then
            pushd $(command git rev-parse --show-toplevel || pwd) > /dev/null;
            if command git add .; then
                echo "All modified files added to stage."
            else
                echo "Error adding all changes to the staging area." >&2
            fi
            popd > /dev/null;
        else
            if command git add "$@"; then
                echo "Files added to stage:"
                for i in "$@"; do
                    echo "- $i"
                done
            else
                echo "Error adding specified files to the staging area." >&2
            fi
        fi
    elif [[ "$1" == "." ]]; then
        command git info
    elif [[ "$1" == "tags" ]]; then
        command git tag --sort=-creatordate -n
    else
        command git "$@"
    fi
}
