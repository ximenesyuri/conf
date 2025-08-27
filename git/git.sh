function git() {
    case "$1" in
    add)
        shift
        if [ -z "$1" ]; then
            repo_root=$(git rev-parse --show-toplevel)
            current_dir=$(pwd)
            selected_files_relative=$(command git status --porcelain | awk '{print $2}' | \
                                      fzf --multi --prompt="Add file to stage: " \
                                          --height=40% --layout=reverse --border)
            if [ -n "$selected_files_relative" ]; then
                readarray -t selected_files_relative_array <<< "$selected_files_relative"
                files_to_add=()
                for file in "${selected_files_relative_array[@]}"; do
                    abs_from_root="$repo_root/$file"
                    rel_from_cwd=$(realpath --relative-to="$current_dir" "$abs_from_root" 2>/dev/null)
                    if [ -z "$rel_from_cwd" ] || [ ! -e "$rel_from_cwd" ]; then
                        echo "Warning: '$file' does not exist here, skipping."
                        continue
                    fi
                    files_to_add+=("$rel_from_cwd")
                done
                if [ "${#files_to_add[@]}" -eq 0 ]; then
                    echo "No selected files exist to add."
                    return 1
                fi
                if command git add "${files_to_add[@]}"; then
                    echo "Files added to stage:"
                    for file in "${files_to_add[@]}"; do
                        echo "- $file"
                    done
                else
                    echo "Error adding selected files to the staging area." >&2
                fi
            fi
        elif [[ "$1" == "." ]]; then
            command git add .
        elif [ "$1" == "all" ]; then
            pushd $(command git rev-parse --show-toplevel || pwd) > /dev/null
            if command git add .; then
                echo "All modified files added to stage."
            else
                echo "Error adding all changes to the staging area." >&2
            fi
            popd > /dev/null
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
        ;; 
    back)
        command git reset --hard HEAD~${2:-1}
        ;;
    feat|fix|doc|conf|chore|ci|ref|notes|libs)
        type="$1"; shift
        message="$*"
        command git commit -m "$type: $message"
        ;;
    ...) command git commit -m "..." ;;
    info|.) git log -1 --oneline; git status ;; 
    branch)
        shift; sub="$1"
        if [[ -z "$sub" ]]; then
            command git branch
            return 
        fi
        case "$sub" in
            "")
                command git branch
                ;;
            new)
                if [ -n "$2" ]; then
                    command git checkout -b "$2"
                else
                    echo "Error: Branch name required. Usage: git branch new <branch-name>"
                    return 1
                fi
                ;;
            list)
                command git branch -a
                ;;
            rm)
                if [ -z "$2" ]; then
                    selected=$(command git branch --format="%(refname:short)" | \
                        fzf --multi --prompt="Branch to delete: " --height=30%)
                    [ -n "$selected" ] && \
                        for branch in $selected; do command git branch -D "$branch"; done
                else
                    command git branch -D "$2"
                fi
                ;;
            send)
                branch_to_push="${2:-HEAD}"
                command git push origin "${branch_to_push}"
                ;;
            *)
                if git show-ref --verify --quiet "refs/heads/$sub"; then
                    git checkout "$sub"
                else
                    echo "Error: Branch '$sub' does not exist."
                    echo "Usage:"
                    echo "  git branch                # List branches"
                    echo "  git branch new <name>     # Create new branch"
                    echo "  git branch <name>         # Checkout existing branch"
                    echo "  git branch rm <name>      # Delete branch"
                    return 1
                fi
                ;; 
        esac
        ;;
    tag)
        shift; sub="$1"
        case "$sub" in
            new)
                tagtype="$2"; msg="$3"
                if [ -z "$tagtype" ]; then
                    echo "Error: Missing tag type (patch, minor, or major)."
                    return 1
                fi
                latest_tag=$(git describe --tags --abbrev=0 2>/dev/null)
                if [ -z "$latest_tag" ]; then
                    new_tag="v0.1.0"
                else
                    IFS='.' read major minor patch <<< "${latest_tag#v}"
                    case "$tagtype" in
                        patch) patch=$((patch + 1));;
                        minor) minor=$((minor + 1)); patch=0;;
                        major) major=$((major + 1)); minor=0; patch=0;;
                        *)
                            echo "Invalid tag type: $tagtype. Use patch, minor, or major." && return 1;;
                    esac
                    new_tag="v$major.$minor.$patch"
                fi
                if [ -n "$msg" ]; then
                    command git tag "$new_tag" -m "$msg"
                else
                    command git tag "$new_tag"
                fi
                echo "Created new tag: $new_tag"
                ;;
            list) command git tag --sort=-creatordate -n ;;
            rm)
                if [ -z "$2" ]; then
                    selected=$(git tag --sort=-creatordate -l | \
                        fzf --multi --prompt="Tag to delete: " --height=30%)
                    [ -n "$selected" ] && \
                        for tag in $selected; do command git tag -d "$tag"; done
                else
                    command git tag -d "$2"
                fi
                ;;
            send)
                latest_tag=$(git describe --tags --abbrev=0 2>/dev/null)
                [ -z "$latest_tag" ] && { echo "Error: No tags found to push."; return 1; }
                command git push origin "$latest_tag"
                ;;
            *) echo "Usage: git tag new/list/rm/send [...]" ;;
        esac
        ;;
    stage)
        shift; sub="$1"
        case "$sub" in
            add)
                selected=$(git status --porcelain | \
                    awk '{if ($1 ~ /^[MARCU?]/) print $2}' | \
                    fzf --multi --prompt="Add file to stage: " --height=30%)
                [ -n "$selected" ] && command git add $selected
                ;;
            list)
                command git diff --cached --name-only
                ;;
            rm)
                if [ -z "$2" ]; then
                    repo_root=$(git rev-parse --show-toplevel)
                    current_dir=$(pwd)
                    staged=$(git diff --cached --name-only | \
                        fzf --multi --prompt="Unstage file: " --height=30%)
                    if [ -n "$staged" ]; then
                        readarray -t files_to_unstage <<< "$staged"
                        files_for_reset=()
                        for file in "${files_to_unstage[@]}"; do
                            abs_from_root="$repo_root/$file"
                            rel_from_cwd=$(realpath --relative-to="$current_dir" "$abs_from_root" 2>/dev/null)
                            if [ -n "$rel_from_cwd" ] && [ -e "$rel_from_cwd" ]; then
                                files_for_reset+=("$rel_from_cwd")
                            else
                                files_for_reset+=("$file")
                            fi
                        done
                        if [ "${#files_for_reset[@]}" -eq 0 ]; then
                            echo "No selected files exist to unstage."
                            return 1
                        fi
                        if git reset HEAD -- "${files_for_reset[@]}" > /dev/null; then
                            echo "Unstaged files:"
                            for f in "${files_to_unstage[@]}"; do
                                echo "- $f"
                            done
                        else
                            echo "Error unstaging files." >&2
                        fi
                    fi
                else
                    if git reset HEAD "$@" > /dev/null; then
                        echo "Unstaged files:"
                        for f in "$@"; do
                            echo "- $f"
                        done
                    else
                        echo "Error unstaging files." >&2
                    fi
                fi
                ;; 
            *)
                echo "Usage: git stage add/list/rm"
                ;; 
        esac
        ;; 
    commit)
        shift; sub="$1"
        case "$sub" in
            new)
                msg=""
                if [ -z "$2" ]; then
                    read -e -p "Commit message: " msg
                else
                    shift
                    msg="$*"
                fi
                [ -z "$msg" ] && { echo "No message provided."; return 1; }
                command git commit -m "$msg"
                ;;
            list)
                command git log --oneline --decorate --graph -n 10
                ;;
            rm)
                base_commit=$(git log --oneline | \
                    fzf --multi --prompt="Select commits to delete (oldest to newest): " --height=50% | \
                    awk '{print $1}' | head -n1 )
                [ -z "$base_commit" ] && { echo "No commit selected."; return 1; }
                command git rebase -i "$base_commit^"
                echo "# In the rebase editor, change 'pick' to 'drop' for unwanted commits."
                ;;
            ammend)
                shift
                git commit --amend -m "$*"
                ;;
            *) echo "Usage: git commit new/list/rm" ;;
        esac
        ;;
    send)
        if [ -z "$2" ]; then
            git push origin HEAD
        else
            git push origin "$2"
        fi
        ;;

    force)
        if [ -z "$2" ]; then
            git push origin HEAD --force
        else
            git push origin --force "$2"
        fi
        ;;
    rebase|reb)
        num="${2:-10}"
        if [[ -z "$num" ]]; then
            num=10
        fi
        if ! [[ "$num" =~ ^[1-9][0-9]*$ ]]; then
            echo "Error: '$num' is not a positive integer."
            echo "Usage: git rebase <n>"
            return 1
        fi
        command git rebase -i HEAD~"$num"
        ;;
    continue) git rebase --continue ;;
    abort) git rebase --abort ;;
    *)
        command git "$@"
        ;;
    esac
}
