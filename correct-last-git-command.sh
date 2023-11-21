# use in ~/.zshrc
# alias gitgud="tryToCorrectMyLastCommand"

tryToCorrectMyLastCommand(){
  previous_command=$(fc -ln -1)
  error_msg=$(eval "$previous_command" 2>&1)
  suggestion=$(echo "$error_msg" | sed -n 'N;s/\n//;s#The most similar command is\t\(.*\)#\1#p') 
  mistake=$(echo "$error_msg" | sed -n "s#.*'\(.*\)' is not a .*#\1#p")
  correct_command=$(echo "$previous_command" | sed s/"$mistake"/"$suggestion"/)
  eval "$correct_command"
}