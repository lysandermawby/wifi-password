#!/usr/bin/env sh

version="0.1.0"

# locate airport(1)
airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
if [ ! -f $airport ]; then
  echo "ERROR: Can't find \`airport\` CLI program at \"$airport\"."
  exit 1
fi

# by default we are verbose (unless non-tty)
if [ -t 1 ]; then
  verbose=1
else
  verbose=
fi

# usage info
usage() {
  cat <<EOF

  Usage: wifi-password [options] [ssid]

  Options:
    -q, --quiet      Only output the password.
    -V, --version    Output version
    -h, --help       This message.
    --               End of options

EOF
}

# parse options
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do
  case $1 in
    -V | --version )
      echo $version
      exit
      ;;
    -q | --quiet )
      verbose=
      ;;
    -h | --help )
      usage
      exit
      ;;
  esac
  shift
done
if [[ "$1" == "--" ]]; then shift; fi

# merge args for SSIDs with spaces
args="$@"

# check for user-provided ssid 
if [ "" != "$args" ]; then
  ssid="$@"
else
  # get current ssid with fallback for newer macOS
  # try airport (works on older macOS, returns empty on newer)
  ssid="`$airport -I 2>/dev/null | awk '/ SSID/ {print substr($0, index($0, $2))}'`"
  # if airport returned nothing, fall back to system_profiler
  if [ "$ssid" = "" ]; then
    ssid="`system_profiler SPAirPortDataType 2>/dev/null | awk -F': ' '/Current Network Information:/{getline; if ($1 ~ /^[ ]+[^ ]+/) {gsub(/^[ ]+|:$/, "", $1); print $1; exit}}'`"
  fi
  if [ "$ssid" = "" ]; then
    echo "ERROR: Could not retrieve current SSID. Are you connected?" >&2
    exit 1
  fi
fi
# warn user about keychain dialog
if [ $verbose ]; then
  echo ""
  echo "\033[90m … getting password for \"$ssid\". \033[39m"
  echo "\033[90m … keychain prompt incoming. \033[39m"
fi

sleep 2

# source: http://blog.macromates.com/2006/keychain-access-from-shell/
pwd="`security find-generic-password -D 'AirPort network password' -ga \"$ssid\" 2>&1 >/dev/null`"

if [[ $pwd =~ "could" ]]; then
  echo "ERROR: Could not find SSID \"$ssid\"" >&2
  exit 1
fi

# clean up password
pwd=$(echo "$pwd" | sed -e "s/^.*\"\(.*\)\".*$/\1/")

if [ "" == "$pwd" ]; then
  echo "ERROR: Could not get password. Did you enter your Keychain credentials?" >&2
  exit 1
fi

# print
if [ $verbose ]; then
  echo "\033[96m ✓ \"$pwd\" \033[39m"
  echo ""
else
  echo $pwd
fi
