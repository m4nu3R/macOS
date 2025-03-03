#!/bin/zsh

# UnActivationLock
# An Activation Lock / iCloud Logout Prompt

# This script checks to see if a machine is Activation locked by a user, and if so,
# it will try to determine if the currently logged in user is the one associated with 
# the activation lock, and prompt the user to turn off Find My Mac.

########################################################################################
# Created by Brian Van Peski - macOS Adventures
########################################################################################
# Current version: 1.6 | See CHANGELOG for full version history.
# Updated: 12/21/2023

# Set logging - Send logs to stdout as well as Unified Log
# Use 'log show --process "logger"'to view logs activity.
function LOGGING {
    echo "${1}"
    /usr/bin/logger "UnActivationLock: ${1}"
}

##############################################################
# USER INPUT 
##############################################################
# Messaging
dialogTitle="Turn off Find My Mac"
dialogMessage="This company device is currently locked to your iCloud account. Please turn off Find My Mac under iCloud > Show More Apps > Find My Mac."
appIcon="/System/Library/PrivateFrameworks/AOSUI.framework/Versions/A/Resources/findmy.icns" #Path to app icon for messaging (optional)
# SwiftDialog Options
swiftDialogOptions=(
  --mini
  --ontop
  --moveable
)

attempts=6 #How many attempts at prompting the user before giving up.
wait_time=40 #How many seconds to wait between user prompts.

# Change to 'true' if you want to *always* prompt the user to log out when Find My Mac
# is enabled, regardless of user-based Activation Lock status.
DisallowFindMy=false

##############################################################
# VARIABLES & FUNCTIONS
##############################################################
currentUser=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
uid=$(id -u "$currentUser")
activationLock=$(/usr/sbin/system_profiler SPHardwareDataType | awk '/Activation Lock Status/{print $NF}')
plist="/Users/$currentUser/Library/Preferences/MobileMeAccounts.plist"
DEPStatus=$(profiles status -type enrollment | grep "Enrolled via DEP" | awk '{print $4}')
FindMyEnabled=$(/usr/libexec/PlistBuddy -c print "$plist" | grep -A1 "FIND_MY_MAC" | awk 'FNR == 2 {print $3}' ) #Checks dictionary to make sure proper user is targeted [if FindMy = then, continue]
KandjiAgent="/Library/Kandji/Kandji Agent.app"
#Path to SwiftDialog
dialogPath="/usr/local/bin/dialog"
dialogApp="/Library/Application Support/Dialog/Dialog.app"

runAsUser() {
  # From https://scriptingosx.com/2020/08/running-a-command-as-another-user
  if [ "$currentUser" != "loginwindow" ]; then
    launchctl asuser "$uid" sudo -u "$currentUser" "$@"
  else
    echo "No user logged in"
    # Uncomment the exit command to make the function exit with an error when no user is logged in
    # exit 1
  fi
}

UserLookup (){
## Fetch all local user accounts, return account with iCloud FindMyStatus enabled.
USER_LIST=($(/usr/bin/dscl /Local/Default -list /Users UniqueID | /usr/bin/awk '$2 >= 500 {print $1}'|tr '\n' ' ' ))
LOGGING "--- Checking Activation Lock status for the following users: $USER_LIST..."
for user in "${USER_LIST[@]}"; do
    plistLookup="/Users/${user}/Library/Preferences/MobileMeAccounts.plist"
    #LOGGING "--- Checking Activation Lock status for $user..."
    if [[ -f $plistLookup ]]; then
      FindMyEnabled=$(/usr/libexec/PlistBuddy -c print "/Users/${user}/Library/Preferences/MobileMeAccounts.plist" | grep -A1 "FIND_MY_MAC" | awk 'FNR == 2 {print $3}' )
      #LOGGING "Find My Status for $user is: $FindMyEnabled"
      if [[ $FindMyEnabled == "true" ]]; then
      LOGGING "Find My is enabled for user $user"
      FindMyUser="$user"
      FindMyEmail=$(/usr/libexec/PlistBuddy -c 'print Accounts:0:AccountID' "/Users/$user/Library/Preferences/MobileMeAccounts.plist")
      fi
    else
      #LOGGING "No iCloud login found for $user"
    fi
done
}
UserDialog (){
  #First check if the app icon exists
  if [ -e "$appIcon" ]; then
    iconCMD=(--icon "$appIcon")
  else
    #If the icon file doesn't exist, set an empty array to omit from dialogs.
    iconCMD=()
  fi

  #If KandjiAgent is installed, use Kandji
  if [[ -d "$KandjiAgent" ]]; then
    /usr/local/bin/kandji display-alert --title "$dialogTitle" --message "$dialogMessage" ${iconCMD[@]}
  #No Kandji, and SwiftDialog is installed, use SwiftDialog
  elif [[ -e "$dialogPath" && -e "$dialogApp" ]]; then
    "$dialogPath" --title "$dialogTitle" --message "$dialogMessage" ${swiftDialogOptions[@]} ${iconCMD[@]}
  #No Kandji and no SwiftDialog, default to osascript w/ icon.
  elif [ -e "$appIcon" ]; then
    runAsUser /usr/bin/osascript -e 'display dialog "'"$dialogMessage"'" with title "'"$dialogTitle"'" with icon POSIX file "'"$appIcon"'" buttons {"Okay"} default button 1 giving up after 15'
  #No Kandji, no SwiftDialog, and no appicon. Use osascript.
  else
    runAsUser /usr/bin/osascript -e 'display dialog "'"$dialogMessage"'" with title "'"$dialogTitle"'" buttons {"Okay"} default button 1 giving up after 15'
  fi
}

##############################################################
#  THE NEEDFUL
##############################################################
LOGGING "Activation Lock Status: $activationLock | ADE-Enrolled: $DEPStatus"
#Check if Kandji Liftoff is running
if pgrep "Liftoff" >/dev/null; then
    LOGGING "--- Liftoff is running. Exiting to wait for apps to finish installing..."
    exit 0
# Check if Activation Lock is enabled.
elif [[ $activationLock == "Enabled" ]]; then
  LOGGING "--- User-Based Activation Lock is: Enabled. Checking local users..."
  UserLookup
  #Determine the FindMy enabled user and see if it matches the currently logged in user.
  if [[ -f "$plist" && "$FindMyUser" == "$currentUser" ]]; then
    dialogAttempts=0
    until [[ $activationLock == "Disabled" ]]
      do
        if (( $dialogAttempts >= $attempts )); then
          LOGGING "Prompts have been ignored after $attempts attempts. Giving up..."
          exit 1
        fi
        LOGGING "--- Found logged in iCloud account '$FindMyUser'... Presenting pane to user and requesting user to log out..."
        open "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane?iCloud"
        runAsUser osascript -e 'tell application "System Settings"' -e 'activate' -e 'end tell'
        UserDialog
        sleep $wait_time
        ((dialogAttempts++))
        export activationLock=$(/usr/sbin/system_profiler SPHardwareDataType | awk '/Activation Lock Status/{print $NF}')
      done
    LOGGING "Activation Lock Status: $activationLock"
    exit 0
    elif [[ $activationLock == "Enabled" && -z $FindMyUser ]]; then
      if /usr/sbin/nvram -xp | grep fmm-mobileme-token-FMM > /dev/null 2>&1; then
        FindMyMac="Enabled"
      else
        FindMyMac="Disabled"
      fi
      LOGGING "--- Activation lock status is $activationLock, and there are no users with a FindMy token associated. FindMyMac is $FindMyMac on this computer. The cached activation lock status or FindMy status in the user's MobileMeAccounts.plist may be incorrect. Alerting admin for further troubleshooting..."
      exit 1
    else
      LOGGING "--- The currently logged in user: '$currentUser' is not the user associated with the Activation Lock.
      --- Activation Lock status is: $activationLock, and is locked by user '$FindMyUser' with account '$FindMyEmail'.
      --- Script will continue to run until the appropriate user logs in and is prompted to turn off Find My.
      Exiting..."
      exit 1
  fi
else
  UserLookup
  # Always prompt if Find My Mac is enabled (optional)
  if [[ $DisallowFindMy == true && "$FindMyUser" == "$currentUser" ]]; then
    dialogAttempts=0
    until [[ $FindMyEnabled == false ]]
      do
        if (( $dialogAttempts >= $attempts )); then
        LOGGING "Prompts have been ignored after $attempts attempts. Giving up..."
        exit 1
        fi
        LOGGING "--- Found logged in iCloud account for user '$FindMyUser' with account '$FindMyEmail'... Presenting pane to user and requesting user to log out of Find My Mac."
        runAsUser open "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane?iCloud"
        runAsUser osascript -e 'tell application "System Settings"' -e 'activate' -e 'end tell'
        UserDialog
        sleep $wait_time
        ((dialogAttempts++))
        #export FindMyStatus
        export FindMyEnabled=$(/usr/libexec/PlistBuddy -c print "$plist" | grep -A1 "FIND_MY_MAC" | awk 'FNR == 2 {print $3}')
      done
  fi
  LOGGING "--- User-based Activation Lock not enabled.
  --- Find My Mac status for $currentUser is: $FindMyEnabled.
  Exiting..."
  exit 0
fi