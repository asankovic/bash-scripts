#!/usr/bin/env bash
#set -x
# Keeping Desktop just for this purpose
readonly defaultTodoFilePath="/Users/$(whoami)/Desktop/todo/.todo"
readonly logFile="./todo.log"
readonly archiveFile="./done.txt"
readonly reportFile="./report.txt"
readonly genericErrorMessage="X Command not executed, please check your input and try again!"
todoFile=""

prepareLogging(){
  touch "$logFile"
  exec 2> "$logFile"
}

createFileFromPath(){
  [ $# -ne 1 ] && return 2

  local directory
  local file
  directory=$(dirname "$1")
  file=$(basename "$1")

  (mkdir -p "${directory}") && (touch "${directory}/${file}")
}

validateOrCreateTodoFile(){
  local targetFilePath="${1:-$defaultTodoFilePath}"
  if [[ ! -e $targetFilePath ]]; then
    local shouldCreate
    #  for some reason, this goes to stderr
    read -rp "Todo file at target location does not exist, but it's crucial to continue. Would you like to create a new one? (Y/[N]): " shouldCreate 2>&1
    case $shouldCreate in
      [yY]) createFileFromPath "$targetFilePath" || echo "Error creating needed files, please try again. Exiting..." && exit 99;;
      * )
        echo "Check your file system or try again by creating a new todo file. Exiting..."
        exit 99;;
    esac
  fi
  todoFile="$targetFilePath"
}

addTodoEntry(){
  addEntryToFile "$todoFile" "$*"
}

addEntryToFile(){
  local file entry
  file=$1
  shift 1
  entry=$*
  if [[ -n "$entry" ]]; then
    #format for file: <optional priority>|<+/- for done>|<text>
    entry="_|-|$entry"
    echo "$entry" >> "$file"
    echo "Entry added!"
  else
    echo "You need to enter something, silly!"
  fi
}

appendTodo(){
  local item text
  item=${1//ITEM/}
  [ "$item" -eq "$item" ] || return 3
  shift 1
  text="$*"
  sed -i'' -e "$item s/$/$text/" "$todoFile"
}

deleteEntry(){
  local deleteItem term
  deleteItem=${1//ITEM/}
  [ "$deleteItem" -eq "$deleteItem" ] || return 3
  shift 1
  term="$*"
  if [[ -z $term ]]; then
    deleteItem+="d"
    sed -i'' -e "$deleteItem" "$todoFile"
  else
    sed -i'' -e "$deleteItem s/$term//" "$todoFile"
  fi
}

deduplicate(){
  declare -r tempFile="./tempDeduplicate"
  awk '!seen[$0]++' "$todoFile" > "$tempFile" && mv "$tempFile" "$todoFile"
}

markComplete(){
  local items done=()
  IFS=',' read -ra items <<< "$*"
  for item in "${items[@]}"; do
    item=${item//ITEM/}
    [ -n "$item" ] && [ "$item" -eq "$item" ] && sed -E -i'' -e "$item s/^([[:alpha:]_]{1})\|[+-]{1}\|(.*)$/\1|+|\2/g" "$todoFile" && done+=("$item")
  done
  [ ${#done[@]} == 0 ] && echo "No items found for marking as complete, check your command and try again." && return 4
  printf -v doneItems ' %s,' "${done[@]}"
  echo "Items marked as done:${doneItems%,}."
}

prioritizeTodo(){
  local item priority
  item=${1//ITEM/}
  [ "$item" -eq "$item" ] || return 3
  shift 1
  priority="$*"
  [[ "$priority" =~ ^[A-Z]{1}$ ]] || return 3
  sed -E -i'' -e "$item s/^[A-Z_]{1}(\|[+-]{1}\|.*)$/$priority\1/g" "$todoFile"
}

deprioritizeTodo(){
  local items done=()
  IFS=',' read -ra items <<< "$*"
  for item in "${items[@]}"; do
    item=${item//ITEM/}
    [ -n "$item" ] && [ "$item" -eq "$item" ] && sed -E -i'' -e "$item s/^[A-Z_]{1}(\|[+-]{1}\|.*)$/_\1/g" "$todoFile" && done+=("$item")
  done
  [ ${#done[@]} == 0 ] && echo "No items found for removing priority, check your command and try again." && return 4
  printf -v doneItems ' %s,' "${done[@]}"
  echo "Priority removed from items:${doneItems%,}."
}

prependTodo(){
  local item text
  item=${1//ITEM/}
  [ "$item" -eq "$item" ] || return 3
  shift 1
  text="$*"
  sed -E -i'' -e "$item s/([A-Z_]{1}\|[+-]{1}\|)(.*)/\1$text\2/" "$todoFile"
}

replace(){
  local item text
  item=${1//ITEM/}
  [ "$item" -eq "$item" ] || return 3
  shift 1
  text="$*"
  sed -E -i'' -e "$item s/([A-Z_]{1}\|[+-]{1}\|).*/\1$text/" "$todoFile"
}

archive(){
  awk -F '|' '{ if($2 == "+") print $0;}' "$todoFile" >> "$archiveFile"
  sed -E -i'' -e '/[A-Z_]{1}\|\+\|.*/d' "$todoFile"
}

report(){
  #  if on mac, make sure gawk is installed
  awk -F '|' 'BEGIN{ time = strftime("%F %T")} {if($2 == "+") done+=1; else open+=1} END {printf("%s\tDONE: %s\t\tOPEN: %s\n", time, done, open)}' "$todoFile" >> "$reportFile"
}

listProjects(){
  if [[ -n "$*" ]]; then
    awk -F '|' "match(\$NF, /\+$*/) {print \$NF}" "$todoFile"
    return
  fi
  awk -F '|' 'match($NF, /\+\w+/) { projects[substr($NF, RSTART, RLENGTH)]++ } END {for (line in projects) print line}' "$todoFile"
}

listPriorities(){
  local project text
  project="$1"
  shift 1
  text="$*"
  if [[ -n "$project" && -n "$text" ]]; then
    awk -F '|' -v project="$project" -v text="$text" '$1 ~ project && $NF ~ text {print $1 " -> " $NF}' "$todoFile"
  elif [[  -n "$project"  ]]; then
    awk -F '|' -v project="$project" '$1 ~ project {print $1 " -> " $NF}' "$todoFile"
  else
    awk -F '|' '$1 ~ /[A-Z]{1}/ {print $1 " -> " $NF}' "$todoFile"
  fi
}

listContexts(){
  if [[ -n "$*" ]]; then
    awk -F '|' "match(\$NF, /\@$*/) {print \$NF}" "$todoFile"
    return
  fi

  awk -F '|' 'match($NF, /\@\w+/) { contexts[substr($NF, RSTART, RLENGTH)]++ } END {for (line in contexts) print line}' "$todoFile"
}

listAll(){
  awk -F '|' '$1 ~ /[A-Z_]{1}/ {print $1 " => #" NR " -> " $NF}' "$todoFile" | sort
}

readUserInput(){
  local command length parameters
  #  for some reason, this goes to stderr
  read -rp "> " command 2>&1
  read -ra command <<< "$command"
  length=${#command[@]}
  parameters=( "${command[@]:1:$length}" )

  case ${command[0]} in
    exit) exit 0;;
    help) echo "I'm lazy, please read it on GitHub.<3";;
    add|a) addTodoEntry "${parameters[@]}";;
    addto|at) addEntryToFile "${parameters[@]}";;
    append|app) appendTodo "${parameters[@]}" || echo "$genericErrorMessage";;
    preppend|prep) prependTodo "${parameters[@]}" || echo "$genericErrorMessage";;
    replace) replace "${parameters[@]}" || echo "$genericErrorMessage";;
    del|rm) deleteEntry "${parameters[@]}" || echo "$genericErrorMessage";;
    do) markComplete "${parameters[@]}";;
    pri|p) prioritizeTodo "${parameters[@]}" || echo "$genericErrorMessage";;
    depri|dp) deprioritizeTodo "${parameters[@]}";;
    listproj|lsprj) listProjects "${parameters[@]}";;
    listcon|lsc) listContexts "${parameters[@]}";;
    listpri|lsp) listPriorities "${parameters[@]}";;
    list|ls) listAll;;
    archive) archive;;
    report) report;;
    deduplicate) deduplicate;;
    *) echo "Unknown command!";;
  esac
}

main(){
  prepareLogging
  validateOrCreateTodoFile "$1"
  while true; do
    readUserInput
  done
}

while getopts "f:" opt; do
    case $opt in
      f) customFile="$OPTARG"
      ;;
      \?) echo "Invalid option -$OPTARG"
      exit 1
      ;;
    esac

    case $OPTARG in
      -*) echo "Option $opt needs a valid argument"
      exit 1
      ;;
    esac
done

main "$customFile"