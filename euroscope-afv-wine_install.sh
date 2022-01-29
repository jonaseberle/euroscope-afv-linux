#!/bin/bash
# Installs VATSIM ATC software (EuroScope and Audio for VATSIM) into a wine environment
# Building on top of the work of Samir Gebran https://forums.vatsim.net/topic/31019-euroscope-on-linux-howto/
# License: MIT

# saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail -o noclobber -o nounset

logFilename="euroscope-afv-wine_install.log"

#black="\033[0;30m"
#blackb="\033[1;30m"
#white="\033[0;37m"
#whiteb="\033[1;37m"
red="\033[0;31m"
#redb="\033[1;31m"
green="\033[0;32m"
greenb="\033[1;32m"
#yellow="\033[0;33m"
#yellowb="\033[1;33m"
#blue="\033[0;34m"
#blueb="\033[1;34m"
#purple="\033[0;35m"
purpleb="\033[1;35m"
#lightblue="\033[0;36m"
#lightblueb="\033[1;36m"
underline="\033[4m"

fEnd="\033[0m"
fSection=$green$underline
fHighlight=$green
fStatus=$purpleb
fInfo=$greenb
fError=$red

function usage() {
  printf "Usage: euroscope-afv-wine_install.sh [<options>]\n"
  printf "  <options>:\n"
  printf "\t%-15s %s\n" "-h|--help" "this help"
  printf "\t%-15s %s\n" "-y|--yes" "no confirmations"
  printf "\t%-15s %s\n" "-v|--verbose" "echo all script commands"
}

function parseArgs() {
  # -allow a command to fail with !’s side effect on errexit
  # -use return value from ${PIPESTATUS[0]}, because ! hosed $?
  ! getopt --test >/dev/null
  if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo -e "$errorC‹getopt --test› failed in this environment.$endC"
    exit 1
  fi

  OPTIONS="yvh"
  LONGOPTS="yes,verbose,help"

  # -regarding ! and PIPESTATUS see above
  # -temporarily store output to be able to check for errors
  # -activate quoting/enhanced mode (e.g. by writing out “--options”)
  # -pass arguments only via   -- "$@"   to separate them correctly
  ! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
  if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    usage
    exit 2
  fi
  # read getopt’s output this way to handle the quoting right:
  eval set -- "$PARSED"

  while true; do
    case "$1" in
    -y | --yes)
      isForce=1
      shift
      ;;
    -v | --verbose)
      isVerbose=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      usage
      exit 3
      ;;
    esac
  done
}

# arguments
isForce=0
isVerbose=0

parseArgs "$@"

if [ $isVerbose == 1 ]; then
  set -x
fi

echo "You should call this program from a fresh (empty) directory where you want your EuroScope/AfV setup with wine."
printf "  Suggestion:        %s\n" "$HOME/VATSIM-ATC/wine"
printf "  Current directory: %s\n" "$PWD" |
  tee -a "$logFilename"
printf "This program will only change files inside this directory. Anyways the built win environment has access to all files that your user has access to.\n"

# check if required programs available in $PATH
for prog in getopts pkill unzip grep wine winetricks wget; do
  if ! type $prog >/dev/null; then
    printf "%bERROR: we need the program ‹%s›\n%b" "${fError}" "$prog" "$fEnd"
    exit 1
  fi
done

wineBin="$(which wine)"
winetricksBin="$(which winetricks)"

printf "\n%bInformation about your system:%b\n" "$fInfo" "$fEnd"
printf "  wine version      : %s\n" "$("$wineBin" --version)" |
  tee -a "$logFilename"
printf "  winetricks version: %s\n" "$("$winetricksBin" --version)" |
  tee -a "$logFilename"

if [ $isForce == 0 ]; then
  printf "%b\nAre you sure you want to create or update the wine environment in the current directory?%b" "$fHighlight" "$fEnd"
  read -p " [y/n] " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

printf "%bFind the output of all commands in ‹%s› if you need it.%b\n" "$fInfo" "$logFilename" "$fEnd"

function download() {
  local _url="$1"
  local _filename="$2"
  if [ -f "$_filename" ]; then
    printf "%bFound ‹%s› in current directory. Not downloading from ‹%s›.\n%b" "$fStatus" "$_filename" "$_url" "$fEnd" |
      tee -a "$logFilename"
    return 0
  fi
  printf "%bDownloading ‹%s› to current directory…\n%b" "$fStatus" "$_url" "$fEnd" |
    tee -a "$logFilename"
  wget "$_url" -O "$_filename"
}

function wine() {
  printf "%bRunning \"WINEARCH=win32 WINEPREFIX=\"$PWD\" wine $*\"…\n%b" "$fStatus" "$fEnd" |
    tee -a "$logFilename"
  WINEARCH=win32 WINEPREFIX="$PWD" "$wineBin" "$@" &>>"$logFilename"
}

function winetricks() {
  printf "%bRunning \"WINEARCH=win32 WINEPREFIX=\"$PWD\" winetricks $*\"…\n%b" "$fStatus" "$fEnd" |
    tee -a "$logFilename"
  WINEARCH=win32 WINEPREFIX="$PWD" "$winetricksBin" "$@" &>>"$logFilename"
}

printf "\n%bConfiguring WINEPREFIX…\n%b" "$fSection" "$fEnd"

printf "%bShutting down other wine processes…\n%b" "$fStatus" "$fEnd"
pkill wineserver || true

# This seems to circumvent the "Mono is missing" prompt
WINEDLLOVERRIDES="mscoree=" wine wineboot
wine winecfg -v win7

printf "\n%bInstalling libs…\n%b" "$fSection" "$fEnd"
# This seems to set the Windows version to WinXP
winetricks --unattended dotnet40
winetricks --unattended dotnet45
winetricks --unattended dotnet46
winetricks --unattended dotnet461
winetricks --unattended dotnet462
winetricks --unattended dotnet472
winetricks --unattended dotnet48
winetricks --unattended iertutil
winetricks --unattended msls31
winetricks --unattended msxml6
winetricks --unattended urlmon
winetricks --unattended vcrun2010
winetricks --unattended vcrun2017
winetricks --unattended wininet

printf "\n%bDownloading programs…\n%b" "$fSection" "$fEnd"

printf "%bDownloading EuroScope…\n%b" "$fStatus" "$fEnd"
esFilename="EuroScopeSetup32.msi"
download https://www.euroscope.hu/install/EuroScopeSetup32.msi "$esFilename"

printf "%bInstalling EuroScope…\n%b" "$fSection" "$fEnd"
wine msiexec /q /l "$logFilename" /a "$esFilename"

# find link "Download latest beta" on EuroScope homepage
printf "%bFinding link \"latest beta\" on EuroScope homepage…\n%b" "$fStatus" "$fEnd"
download https://www.euroscope.hu/wp/ es-index.html
_esBetaUrl=$(grep -Eo '<a.*>Download latest beta' es-index.html | grep -Eo 'http.*\.zip')
printf "%bDownloading EuroScope beta…\n%b" "$fStatus" "$fEnd"
esBetaFilename="EuroScope-Beta.zip"
download "$_esBetaUrl" "$esBetaFilename"

printf "%bApplying EuroScope beta…\n%b" "$fSection" "$fEnd"
unzip -o $esBetaFilename -d drive_c/Program\ Files/EuroScope/

printf "%bDownloading Audio for VATSIM…\n%b" "$fStatus" "$fEnd"
afvFilename="Audio for VATSIM.msi"
download https://audio.vatsim.net/downloads/standalone "$afvFilename"

printf "%bInstalling Audio for VATSIM…\n%b" "$fSection" "$fEnd"
wine msiexec /q /l "$logFilename" /a "$afvFilename"

printf "%bSimulating shutdown…\n%b" "$fInfo" "$fEnd"
wine wineboot --shutdown

printf "\n%bInstallation of EuroScope and AfV is finished.\n%b" "$fSection" "$fEnd"
printf "You can run them from your start menu (entries are in %s)\n" "$HOME/.local/share/applications/wine"
printf "or from the command line:\n"

printf "\nAudio for VATSIM:\n"
printf "  %bWINEDEBUG=-all WINEPREFIX=$PWD wine \"$PWD/drive_c/AudioForVATSIM/AudioForVATSIM.exe\"\n%b" "$fInfo" "$fEnd"
printf "\nEuroScope:\n"
printf "  %bWINEDEBUG=-all WINEPREFIX=$PWD wine \"$PWD/drive_c/Program Files/EuroScope/EuroScope.exe\"\n%b" "$fInfo" "$fEnd"

printf "\nUseful tools:\n"
printf "  winecfg (wine confguration, for example: set up your Documents folder):\n"
printf "    %bWINEARCH=win32 WINEPREFIX=$PWD winecfg\n%b" "$fInfo" "$fEnd"
printf "  winetricks (try to solve dependency problems):\n"
printf "    %bWINEARCH=win32 WINEPREFIX=$PWD winetricks\n%b" "$fInfo" "$fEnd"
printf "  Stop rogue win processes:\n"
printf "    %bWINEARCH=win32 WINEPREFIX=$PWD wine wineboot --shutdown\n%b" "$fInfo" "$fEnd"
printf "    %bpkill wine; pkill wineserver\n%b" "$fInfo" "$fEnd"

printf "\nThis is a community effort. Please report findings and improvements on https://github.com/jonaseberle/euroscope-afv-wine\n"
