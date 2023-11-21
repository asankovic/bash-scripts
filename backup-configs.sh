#!/usr/bin/env bash

readonly defaultExportDir="./personal-configs"
readonly defaultLogFile="./backupConfigs.log"
# specific for my case, needs to be set up manually
readonly defaultItermSourceDir="/Users/$(whoami)/Documents/configurations"
readonly defaultIntellijConfigZip="/Users/$(whoami)/Documents/configurations/IntellijSettings.zip"
# should be at a predefined location
readonly rectangleConfigFile="/Users/$(whoami)/Library/Preferences/com.knollsoft.Rectangle.plist"
readonly altTabConfigFile="/Users/$(whoami)/Library/Preferences/com.lwouis.alt-tab-macos.plist"
readonly alfredConfigDir="/Users/$(whoami)/Library/Application Support/Alfred/Alfred.alfredpreferences"
readonly alfredConfigFile="/Users/$(whoami)/Library/Application Support/Alfred/prefs.json"

exportDir=""

preparePrerequisites(){
  local targetExportDir="${1:-$defaultExportDir}"
   if [[ ! -d $targetExportDir  ]]; then
     mkdir -p "$targetExportDir" || (echo "Error creating initial folder structure!" && exit 1)
   fi

  exportDir="$targetExportDir"
  touch "$defaultLogFile"
  # redirect all output to log file, in specified format...keeping old logs
  exec > >(while read -r line; do printf "[%s]\t%s\n" "$(date +%F_%T)" "$line" >> $defaultLogFile; done) 2>&1
}

backupVim(){
  echo "Starting Vim backup..."

  local vimExportDir="$exportDir/vim"
  mkdir -p "$vimExportDir"
  cp -v ~/.ideavimrc "$vimExportDir"
  cp -v ~/.vimrc "$vimExportDir"

  echo "Vim backup finished!"
}

backupIterm2(){
  echo "Starting Iterm2 backup..."

  local itermSourceDir="${2:-$defaultItermSourceDir}"
  local itermExportDir="$1/iterm2"
  mkdir -p "$itermExportDir"
  cp -v "$itermSourceDir/com.googlecode.iterm2.plist" "$itermExportDir"

  echo "Iterm2 backup finished!"
}

backupZshrc(){
  echo "Starting Zshrc backup..."

  local zshrcExportDir="$1/zshrc"
  mkdir -p "$zshrcExportDir"
  cp -v  ~/.zshrc "$zshrcExportDir"
  cp -v  ~/.p10k.zsh "$zshrcExportDir"

  echo "Zshrc backup finished!"
}

backupTerminal(){
  echo "Starting Terminal backup..."

  local terminalExportDir="$exportDir/terminal"
  mkdir -p "$terminalExportDir"
  backupIterm2 "$terminalExportDir" "$1"
  backupZshrc "$terminalExportDir"

  echo "Terminal backup finished!"
}

backupRectangle(){
  echo "Starting Rectangle backup..."

  local rectangleExportDir="$1/rectangle"
  mkdir -p "$rectangleExportDir"
  cp -v "$rectangleConfigFile" "$rectangleExportDir"

  #  rectangle config can also be exported in json, but it needs to be done manually through app
  [[ -n "$2" ]] && cp -v "$2" "$rectangleExportDir"

  echo "Finished Rectangle backup!"
}

backupAltTab(){
  echo "Starting AltTab backup..."

  local altTabExportDir="$1/alt-tab"
  mkdir -p "$altTabExportDir"
  cp -v "$altTabConfigFile" "$altTabExportDir"

  echo "Finished AltTab backup!"
}

backupAlfred(){
  echo "Starting Alfred backup..."

  local alfredExportDir="$1/alfred"
  mkdir -p "$alfredExportDir"
  cp -v "$alfredConfigFile" "$alfredExportDir"
  # zipping in  this case, because lots of files
  zip -r "$alfredExportDir/alfredConfig.zip" "$alfredConfigDir"

  echo "Finished Alfred backup!"
}

backupMacApps(){
  echo "Starting backing up Mac apps..."

  local macExportDir="$exportDir/mac-apps"
  mkdir -p "$macExportDir"
  backupRectangle "$macExportDir" "$1"
  backupAltTab "$macExportDir"
  backupAlfred "$macExportDir"

  echo "Finished backing up Mac apps!"
}

backupIntelliJ(){
  echo "Starting IntelliJ backup..."

  local intellijZipFile="${2:-$defaultIntellijConfigZip}"
  local intellijExportDir="$exportDir/intellij"
  mkdir -p "$intellijExportDir"
  # zip needs to be exported by hand...
  cp -v "$intellijZipFile" "$intellijExportDir"

  echo "Finished IntelliJ backup!"
}

backupHomebrew(){
  echo "Starting Homebrew backup..."

  [[ $(command -v brew) != "" ]] || (echo "Homebrew is not installed, skipping!" && return 1)

  local homebrewExportDir="$exportDir/hombrew"
  mkdir -p "$homebrewExportDir"
  brew bundle dump -f --file "$homebrewExportDir/BrewDump"

  echo "Finished Homebrew backup!"
}

backupConfigs(){
  preparePrerequisites "$1"
  backupVim
  backupTerminal "$2"
  backupMacApps "$3"
  backupIntelliJ "$4"
  backupHomebrew
}

while getopts "d:i:r:l:" opt; do
    case $opt in
      d) customDir="$OPTARG"
      ;;
      i) itermDir="$OPTARG"
      ;;
      r) rectangleJson="$OPTARG"
      ;;
      l) intellijZip="$OPTARG"
      ;;
      \?) echo "Invalid option -$OPTARG" >&2
      exit 1
      ;;
    esac

    case $OPTARG in
      -*) echo "Option $opt needs a valid argument" >&2
      exit 1
      ;;
    esac
done

backupConfigs "$customDir" "$itermDir" "$rectangleJson" "$intellijZip"