#!/bin/bash

#Global variables
emuDecksettingsFile="$HOME/emudeck/settings.sh"

emuDeckEmuTypeFlatpak="Flatpak"
emuDeckEmuTypeAppImage="AppImage"
emuDeckEmuTypeBinary="Binary"
emuDeckEmuTypeWindows="Windows"
emuDeckEmuTypeOther="Other"

function startLog() {
	funcName="$1"
	mkdir -p "$HOME/emudeck/logs"
	logFile="$HOME/emudeck/logs/$funcName.log"

	touch "$logFile"

	exec &> >(tee -a "$logFile")
}

function stopLog(){
	echo "NYI"
}

function getScreenAR(){
	local productName
	productName=$(getProductName)
	case $productName in
		Win600)			return=169		;;
		Jupiter)		return=1610 	;;
		*)				resolution=$(xrandr --current | grep 'primary' | uniq | awk '{print $4}'| cut -d '+' -f1)
						Xaxis=$(echo "$resolution" | awk '{print $1}' | cut -d 'x' -f2)
						Yaxis=$(echo "$resolution" | awk '{print $1}' | cut -d 'x' -f1)

						screenWidth=$Xaxis
						screenHeight=$Yaxis


						##Is rotated?
						if [[ $Yaxis > $Xaxis ]]; then
							screenWidth=$Yaxis
							screenHeight=$Xaxis
						fi

						aspectRatio=$(awk -v screenWidth="$screenWidth" -v screenHeight="$screenHeight" 'BEGIN{printf "%.2f\n", (screenWidth/screenHeight)}')
						if [ "$aspectRatio" == 1.60 ]; then
							ar=1610
						elif [ "$aspectRatio" == 1.78 ]; then
							ar=169
						else
							ar=0
						fi
						return=$ar 		;;
	esac

	echo $return
}

function pause(){
   read -rp "$*"
}

# keyword replacement file. Only matches start of word
function changeLine() {
	local KEYWORD=$1; shift
	local REPLACE=$1; shift
	local FILE=$1

	local OLD=$(escapeSedKeyword "$KEYWORD")
	local NEW=$(escapeSedValue "$REPLACE")

	echo "Updating: $FILE - $OLD to $NEW"
	#echo "Old: ""$(cat "$FILE" | grep "^$OLD")"
	sed -i "/^${OLD}/c\\${NEW}" "$FILE"
	#echo "New: ""$(cat "$FILE" | grep "^$OLD")"

}
function escapeSedKeyword(){
	local INPUT=$1;
	printf '%s\n' "$INPUT" | sed -e 's/[]\/$*.^[]/\\&/g'
}

function escapeSedValue(){
	local INPUT=$1
	printf '%s\n' "$INPUT" | sed -e 's/[\/&]/\\&/g'
}

function getSDPath(){
	if [ -b "/dev/mmcblk0p1" ]; then
		findmnt -n --raw --evaluate --output=target -S /dev/mmcblk0p1
	fi
}

function getProductName(){
	cat /sys/devices/virtual/dmi/id/product_name
}

function testRealDeck(){
	case $(getProductName) in
	  'Win600'|'Jupiter') 	isRealDeck=true
	;;
	  *)
		isRealDeck=false
	;;
	esac
}

function testLocationValid(){
	local locationName=$1
	local testLocation=$2
	local result=""

	if [[ "$testLocation" == *" "* ]]; then
		result="Invalid: $locationName contains spaces"
	else
		touch "$testLocation/testwrite"
		if [ ! -f  "$testLocation/testwrite" ]; then
			result="Invalid: $locationName not Writable"
		else
			ln -s "$testLocation/testwrite" "$testLocation/testwrite.link"
			if [ ! -f  "$testLocation/testwrite.link" ]; then
				result="Invalid: $locationName not Linkable"
			else
				result="Valid"
			fi
			rm -f "$testLocation/testwrite.link"
		fi
		rm -f "$testLocation/testwrite"
	fi
	echo "$result"
}


function testLocationValidRelaxed(){
	local locationName=$1
	local testLocation=$2
	local return=""

	touch "$testLocation/testwrite"

	if [ ! -f  "$testLocation/testwrite" ]; then
		result="Invalid: $locationName not Writable"
	else
		result="Valid"
	fi
	rm -f "$testLocation/testwrite"
	echo $result
}

function makeFunction(){

	find "$1" -type f -iname "$2" | while read -r file
		do

			folderOverride="$(basename "${file}")"
			foldername="$(dirname "${file}")"
			coreName="$(basename "${foldername}")"
			echo "RetroArch_${folderOverride%.*}_bezelOn(){"
			IFS=$'\n'
			for line in $(cat "$file")
			do
				local option=$(echo "$line" | awk '{print $1}')
				local value=$(echo "$line" | awk '{print $3}')
				echo "RetroArch_setOverride '$folderOverride' '$coreName'  '$option' '$value'"
			done
			echo '}'
		done
}

function deleteConfigs(){

	find "$HOME/.config/EmuDeck/backend/configs/org.libretro.RetroArch/config/retroarch/config" -type f -iname "*.opt" -o -type f -iname "*.cfg"| while read file
		do
			rm "$file"
		done
}


function customLocation(){
	zenity --file-selection --directory --title="Select a destination for the Emulation directory." 2>/dev/null
}

function refreshSource(){
	source "$EMUDECKGIT/functions/all.sh"
}

function setAllEmuPaths(){
	for func in $(compgen -A 'function' | grep '_setEmulationFolder')
		 do  $func
	done
}

function setSetting () {
	local var=$1
	local new_val=$2
	settingExists=$(grep -rw "$emuDecksettingsFile" -e "$var")
	if [[ $settingExists == '' ]]; then
		#insert setting to end
		echo "variable not found in settings. Adding $var=$new_val to $emuDecksettingsFile"
		sed -i -e '$a\'"$var=$new_val" "$emuDecksettingsFile"
	elif [[ ! $settingExists == '' ]]; then
		echo "Old value $settingExists"
			if [[ $settingExists == "$var=$new_val" ]]; then
				echo "Setting unchanged, skipping"
			else
				changeLine "$var=" "$var=$new_val" "$emuDecksettingsFile"
			fi
	fi
	#Update values
	# shellcheck source=settings.sh
	source "$emuDecksettingsFile"
}

function installAll(){
	for func in $(compgen -A 'function' | grep '\_install$')
		 do  $func
	done
}


function initAll(){
	for func in $(compgen -A 'function' | grep '\_init$')
		 do  $func
	done
}

function updateOrAppendConfigLine(){
	local configFile=$1
	local option=$2
	local replacement=$3

	local fullPath=$(dirname "$configFile")
	mkdir -p "$fullPath"
	touch "$configFile"

	local optionFound=$(grep -rnw  "$configFile" -e "$option")
	if [[ "$optionFound" == '' ]]; then
		echo "appending: $replacement to $configFile"
		echo "$replacement" >> "$configFile"
	else
		changeLine "$option" "$replacement" "$configFile"
	fi
}

function getEnvironmentDetails(){
	local sdpath=$(getSDPath)
	local sdValid=$(testLocationValid "sd" "$sdpath")
	if [ -f "$HOME/.config/EmuDeck/.finished" ]; then
		firstRun="false"
	else
		firstRun="true"
	fi
	local uname=$(uname -a)
	local productName=$(getProductName)
	local aspectRatio=$(getScreenAR)
	local json="{ \"Home\": \"$HOME\", \"Hostname\": \"$HOSTNAME\", \"Username\": \"$USER\", \"SDPath\": \"$sdpath\", \"IsSDValid?\": \"$sdValid\", \"FirstRun?\": \"$firstRun\",\"ProductName\": \"$productName\",\"AspectRatio\": \"$aspectRatio\",\"UName\": \"$uname\" }"
	jq -r <<< "$json"
}

function getSetting(){
	local setting=$1
	cut -d "=" -f2 <<< "$(grep -r "^${setting}=" "$emuDecksettingsFile")"
}

function createUpdateSettingsFile(){
	#!/bin/bash

	if [ ! -e "$emuDecksettingsFile" ]; then
		echo "#!/bin/bash"> "$emuDecksettingsFile"
	fi
	local defaultSettingsList=()
	defaultSettingsList+=("expert=false")
	defaultSettingsList+=("doSetupRA=true")
	defaultSettingsList+=("doSetupDolphin=true")
	#defaultSettingsList+=("doSetupPCSX2=true")
	defaultSettingsList+=("doSetupRPCS3=true")
	defaultSettingsList+=("doSetupYuzu=true")
	defaultSettingsList+=("doSetupCitra=true")
	defaultSettingsList+=("doSetupDuck=true")
	defaultSettingsList+=("doSetupCemu=true")
	defaultSettingsList+=("doSetupXenia=false")
	defaultSettingsList+=("doSetupRyujinx=true")
	defaultSettingsList+=("doSetupMAME=true")
	defaultSettingsList+=("doSetupPrimehack=true")
	defaultSettingsList+=("doSetupPPSSPP=true")
	defaultSettingsList+=("doSetupXemu=true")
	defaultSettingsList+=("doSetupESDE=true")
	defaultSettingsList+=("doSetupPegasus=false")
	defaultSettingsList+=("doSetupSRM=true")
	defaultSettingsList+=("doSetupPCSX2QT=true")
	defaultSettingsList+=("doSetupScummVM=true")
	defaultSettingsList+=("doSetupVita3K=true")
	defaultSettingsList+=("doSetupRMG=true")
	#defaultSettingsList+=("doSetupMelon=true")
	defaultSettingsList+=("doSetupMGBA=true")
	defaultSettingsList+=("doSetupFlycast=true")
	defaultSettingsList+=("doSetupSupermodel=true")
	defaultSettingsList+=("doInstallSRM=true")
	defaultSettingsList+=("doInstallESDE=true")
	defaultSettingsList+=("doInstallPegasus=false")
	defaultSettingsList+=("doInstallRA=true")
	defaultSettingsList+=("doInstallDolphin=true")
	#defaultSettingsList+=("doInstallPCSX2=true")
	defaultSettingsList+=("doInstallMAME=true")
	defaultSettingsList+=("doInstallRyujinx=true")
	defaultSettingsList+=("doInstallRPCS3=true")
	defaultSettingsList+=("doInstallYuzu=true")
	defaultSettingsList+=("doInstallCitra=true")
	defaultSettingsList+=("doInstallDuck=true")
	defaultSettingsList+=("doInstallCemu=true")
	defaultSettingsList+=("doInstallXenia=true")
	defaultSettingsList+=("doInstallPrimeHack=true")
	defaultSettingsList+=("doInstallPPSSPP=true")
	defaultSettingsList+=("doInstallXemu=true")
	defaultSettingsList+=("doInstallPCSX2QT=true")
	defaultSettingsList+=("doInstallScummVM=true")
	defaultSettingsList+=("doInstallVita3K=true")
	#defaultSettingsList+=("doInstallMelon=false")
	defaultSettingsList+=("doInstallMGBA=false")
	defaultSettingsList+=("doInstallFlycast=true")
	defaultSettingsList+=("doInstallSupermodel=true")
	defaultSettingsList+=("doInstallCHD=true")
	defaultSettingsList+=("doInstallPowertools=false")
	defaultSettingsList+=("doInstallGyro=false")
	defaultSettingsList+=("doInstallHomeBrewGames=false")
	defaultSettingsList+=("installString='Installing'")
	defaultSettingsList+=("RABezels=true")
	defaultSettingsList+=("RAautoSave=false")
	defaultSettingsList+=("duckWide=false")
	defaultSettingsList+=("DolphinWide=false")
	defaultSettingsList+=("DreamcastWide=false")
	defaultSettingsList+=("BeetleWide=false")
	defaultSettingsList+=("pcsx2QTWide=false")
	defaultSettingsList+=("emulationPath=$HOME/Emulation")
	defaultSettingsList+=("romsPath=$HOME/Emulation/roms")
	defaultSettingsList+=("toolsPath=$HOME/Emulation/tools")
	defaultSettingsList+=("biosPath=$HOME/Emulation/bios")
	defaultSettingsList+=("savesPath=$HOME/Emulation/saves")
	defaultSettingsList+=("storagePath=$HOME/Emulation/storage")
	defaultSettingsList+=("ESDEscrapData=$HOME/Emulation/tools/downloaded_media")
	defaultSettingsList+=("esdeTheme=EPICNOIR")
	defaultSettingsList+=("doSelectWideScreen=false")
	defaultSettingsList+=("doRASignIn=false")
	defaultSettingsList+=("doRAEnable=false")
	defaultSettingsList+=("doESDEThemePicker=false")
	defaultSettingsList+=("doSelectEmulators=false")
	defaultSettingsList+=("doResetEmulators=false")
	defaultSettingsList+=("XemuWide=false")
	#defaultSettingsList+=("achievementsPass=false")
	#defaultSettingsList+=("achievementsUser=false")
	defaultSettingsList+=("arClassic3D=43")
	defaultSettingsList+=("arDolphin=43")
	defaultSettingsList+=("arSega=43")
	defaultSettingsList+=("arSnes=43")
	defaultSettingsList+=("RAHandClassic2D=false")
	defaultSettingsList+=("RAHandClassic3D=false")
	defaultSettingsList+=("RAHandHeldShader=false")

	tmp=$(mktemp)
	#sort "$emuDecksettingsFile" | uniq -u > "$tmp" && mv "$tmp" "$emuDecksettingsFile"

	cat "$emuDecksettingsFile" | awk '!unique[$0]++' > "$tmp" && mv "$tmp" "$emuDecksettingsFile"
	for setting in "${defaultSettingsList[@]}"
		do
			local settingName=$(cut -d "=" -f1 <<< "$setting")
			local settingVal=$(cut -d "=" -f2 <<< "$setting")
			if grep -r "^${settingName}=" "$emuDecksettingsFile" &>/dev/null; then
				echo "Setting: $settingName found. CurrentValue: $(getSetting "$settingName")"
			else
				echo "Setting: $settingName NOT found. adding to $emuDecksettingsFile with default value: $settingVal"
				setSetting "$settingName" "$settingVal"
			fi
		done


}

function checkForFile(){
	local file=$1
	local delete=$2
	local finished=false
	while [ $finished == false ]
	do
		test=$(test -f "$file" && echo true)
		  if [[ $test == true ]]; then
				finished=true;
			  clear
			if [[ $delete == 'delete' ]]; then
				  rm "$file"
			fi
			echo 'true';
			break
		  fi
	done
}

function getLatestReleaseURLGH(){
	local repository=$1
	local fileType=$2
	local fileNameContains=$3
	local url
	#local token=$(tokenGenerator)

	if [ "$url" == "" ]; then
		url="https://api.github.com/repos/${repository}/releases/latest"
	fi

	curl -fSs "$url" | \
		jq -r '[ .assets[] | select(.name | contains("'"$fileNameContains"'") and endswith("'"$fileType"'")).browser_download_url ][0] // empty'
}

function getReleaseURLGH(){
	local repository=$1
	local fileType=$2
	local url
	local fileNameContains=$3
	#local token=$(tokenGenerator)

# 	if [ "$system" == "darwin" ]; then
# 		fileType="dmg"
# 	fi
#
# 	if [ "$system" == "darwin" ]; then
# 		fileType="dmg"
# 	fi

	if [ "$url" == "" ]; then
		url="https://api.github.com/repos/$repository/releases"
	fi

	curl -fSs "$url" | \
		jq -r '[ .[].assets[] | select(.name | contains("'"$fileNameContains"'") and endswith("'"$fileType"'")).browser_download_url ][0] // empty'
}

function linkToSaveFolder(){
	local emu=$1
	local folderName=$2
	local path=$3

	if [ ! -d "$savesPath/$emu/$folderName" ]; then
		if [ ! -L "$savesPath/$emu/$folderName" ]; then
			mkdir -p "$savesPath/$emu"
			setMSG "Linking $emu $folderName to the Emulation/saves folder"
			mkdir -p "$path"
			ln -snv "$path" "$savesPath/$emu/$folderName"
		fi
	else
		if [ ! -L "$savesPath/$emu/$folderName" ]; then
			echo "$savesPath/$emu/$folderName is not a link. Please check it."
		else
			if [ $(readlink $savesPath/$emu/$folderName) == $path ]; then
				echo "$savesPath/$emu/$folderName is already linked."
				echo "     Target: $(readlink $savesPath/$emu/$folderName)"
			else
				echo "$savesPath/$emu/$folderName not linked correctly."
				unlink "$savesPath/$emu/$folderName"
				linkToSaveFolder "$emu" "$folderName" "$path"
			fi
		 fi
	fi

}

function moveSaveFolder(){
	local emu=$1
	local folderName=$2
	local path=$3

	local linkedTarget=$(readlink -f "$savesPath/$emu/$folderName")

	unlink "$savesPath/$emu/$folderName"

	if [[ ! -e "$savesPath/$emu/$folderName" ]]; then
		mkdir -p "$savesPath/$emu/$folderName"
		if [[ "$linkedTarget" == "$path" ]]; then
			setMSG "Moving $emu $folderName to the Emulation/saves/$emu/$folderName folder"
			rsync -avh "$path/" "$savesPath/$emu/$folderName" && mv "$path" "${path}.bak"
			ln -sn  "$savesPath/$emu/$folderName" "$path"
		fi
	fi

}


#
#	local Shortcutlocation=$1
#	local name=$2
#	local exec=$3
#	local terminal=$4 #Optional
#
#
function createDesktopShortcut(){


	local Shortcutlocation=$1
	local name=$2
	local exec=$3
	local terminal=$4
	local icon

	rm -f "$Shortcutlocation"

	balooctl check

	mkdir -p "$HOME/.local/share/applications/"

	mkdir -p "$HOME/.local/share/icons/emudeck/"
	cp -v "$EMUDECKGIT/icons/$(cut -d " " -f1 <<< "$name")."{svg,jpg,png} "$HOME/.local/share/icons/emudeck/" 2>/dev/null
	icon=$(find "$HOME/.local/share/icons/emudeck/" -type f -iname "$(cut -d " " -f1 <<< "$name").*")

	if [ -z "$icon" ]; then
		icon="steamdeck-gaming-return"
	fi

	if [ -z "$terminal" ]; then
		terminal="False"
	fi

	echo "#!/usr/bin/env xdg-open
	[Desktop Entry]
	Name=$name
	Exec=$exec
	Icon=$icon
	Terminal=$terminal
	Type=Application
	Categories=Game;
	StartupNotify=false" > "$Shortcutlocation"
	chmod +x "$Shortcutlocation"

	balooctl check

	echo "$Shortcutlocation created"
}

#desktopShortcutFieldUpdate "$shortcutFile" "Field" "NewValue"
function desktopShortcutFieldUpdate(){
	local shortcutFile=$1
	local shortcutKey=$2
	local shortcutValue=$3
	local name
	local icon

	if [ -f "$shortcutFile" ]; then
		# update icon if name is updated
		if [ "$shortcutKey" == "Name" ]; then
			name=$shortcutValue
			cp -v "$EMUDECKGIT/icons/$(cut -d " " -f1 <<< "$name").{svg,jpg,png}" "$HOME/.local/share/icons/emudeck/" 2>/dev/null
			icon=$(find "$HOME/.local/share/icons/emudeck/" -type f \( -iname "$(cut -d " " -f1 <<< "$name").svg" -o -iname "$(cut -d " " -f1 <<< "$name").jpg" -o -iname "$(cut -d " " -f1 <<< "$name").png" \) -print -quit)
			echo "Icon Found: $icon"
			if [ -n "$icon" ]; then
				#desktopShortcutFieldUpdate "$shortcutFile" "Icon" "$icon"
				sed -i "s#Icon\\s*=\\s*.*#Icon=$icon#g" "$shortcutFile"
				sed -E -i "s|Icon\\s*=\\s*.*|Icon=$icon|g" "$shortcutFile"
			fi
		fi
		sed -E -i "s|$shortcutKey\\s*=\\s*.*|$shortcutKey=$shortcutValue|g" "$shortcutFile"
		balooctl check
	fi
}


#iniFieldUpdate "$iniFilePath" "General" "LoadPath" "$storagePath/$emuName/Load" "separator!"
function iniFieldUpdate() {
	local iniFile="$1"
	local iniSection="${2:-}"
	local iniKey="$3"
	local iniValue="$4"
	local separator="${5:- = }"

	if [ -f "$iniFile" ]; then
		# Create the section if it doesn't exist.
		if [ -n "$iniSection" ] && ! grep -q "\[$iniSection\]" "$iniFile"; then
			echo "Creating Header [$iniSection]"
			if [ "$(wc -l < "$iniFile")" -gt 0 ]; then
				# Append a newline before adding the new section
				echo >> "$iniFile"
			fi
			# Escape special characters in the section header
			escapedSection=$(echo "$iniSection" | sed 's/[&/\]/\\&/g')
			echo "[$escapedSection]" >> "$iniFile"
			echo "Creating [$iniSection] key $iniKey$separator$iniValue"
			echo "$iniKey$separator$iniValue" >> "$iniFile"
		else
			# If the key doesn't exist in the section, create it one line below the section.
			# Otherwise, update the value.
			local startLineNumber=''
			local endLineNumber=''
			if [ -n "$iniSection" ]; then
				# Escape special characters in the section header
				escapedSection=$(echo "$iniSection" | sed 's/[&/\]/\\&/g')
				startLineNumber=$(awk -v section="$escapedSection" 'BEGIN{FS=OFS="|"} $0=="["section"]"{print NR; exit}' "$iniFile")
				if [ -n "$startLineNumber" ]; then
					endLineNumber=$(awk -v start="$startLineNumber" -F ']' 'NR > start && /^\[/ {print NR-1; exit}' "$iniFile")
				fi
			fi

			if [ -n "$startLineNumber" ] && [ -n "$endLineNumber" ]; then
				if ! grep -q "^$iniKey$separator" <(sed -n "${startLineNumber},${endLineNumber}p" "$iniFile"); then
					echo "Creating [$iniSection] key $iniKey$separator$iniValue"
					sed -i "${startLineNumber}a$iniKey$separator$iniValue" "$iniFile"
				else
					echo "Updating [$iniSection] key $iniKey$separator$iniValue"
					sed -i "/^\[$escapedSection\]/,/^\[/ s|^$iniKey$separator.*|$iniKey$separator$iniValue|" "$iniFile"
				fi
			elif ! grep -q "^$iniKey$separator" "$iniFile"; then
				echo "Creating key $iniKey$separator$iniValue"
				echo "$iniKey$separator$iniValue" >> "$iniFile"
			else
				echo "Updating key $iniKey$separator$iniValue"
				sed -i "s|^$iniKey$separator.*|$iniKey$separator$iniValue|" "$iniFile"
			fi
		fi
	else
		echo "Can't update missing INI file: $iniFile"
	fi
}


function iniSectionUpdate() {
	local file="$1"
	local section_name="$2"
	local new_content="$3"
	local tmp_file=$(mktemp)

	local inside_section=0

	while IFS= read -r line; do

		if [[ "$line" =~ ^\[$section_name\] ]]; then
			inside_section=1
			echo "$line"
			echo "$new_content"
			continue
		fi

		if [[ "$line" =~ ^\[ ]] && [[ ! "$line" =~ ^\[$section_name\] ]] && [[ $inside_section -eq 1 ]]; then
			echo "$old_content"
			inside_section=0
		fi

		if [[ $inside_section -eq 1 ]]; then
			continue
		fi

		echo "$line"

	local old_content="$line"

	done < "$file" > "$tmp_file"

	if [[ $inside_section -eq 1 ]]; then
		echo "$old_content"
	fi

	mv "$tmp_file" "$file"
}


safeDownload() {
	local name="$1"
	local url="$2"
	local outFile="$3"
	local showProgress="$4"
	local headers="$5"

	echo "safeDownload()"
	echo "- $name"
	echo "- $url"
	echo "- $outFile"
	echo "- $showProgress"
	echo "- $headers"


	if [ "$showProgress" == "true" ] || [[ $showProgress -eq 1 ]]; then
		request=$(curl -w $'\1'"%{response_code}" --fail -L "$url" -H "$headers" -o "$outFile.temp" 2>&1 | tee >(stdbuf -oL tr '\r' '\n' | sed -u 's/^ *\([0-9][0-9]*\).*\( [0-9].*$\)/\1\n#Download Speed\:\2/' | zenity --progress --title "Downloading $name" --width 600 --auto-close --no-cancel 2>/dev/null) && echo $'\2'${PIPESTATUS[0]})
	else
		request=$(curl -w $'\1'"%{response_code}" --fail -L "$url" -H "$headers" -o "$outFile.temp" 2>&1 && echo $'\2'0 || echo $'\2'$?)
	fi
	requestInfo=$(sed -z s/.$// <<< "${request%$'\1'*}")
	returnCodes="${request#*$'\1'}"
	httpCode="${returnCodes%$'\2'*}"
	exitCode="${returnCodes#*$'\2'}"
	echo "$requestInfo"
	echo "HTTP response code: $httpCode"
	echo "CURL exit code: $exitCode"
	if [ "$httpCode" = "200" ] && [ "$exitCode" == "0" ]; then
		echo "$name downloaded successfully";
		mv -v "$outFile.temp" "$outFile"
		return 0
	else
		echo "$name download failed"
		rm -f "$outFile.temp"
		return 1
	fi
}

flushEmulatorLaunchers(){

    local name="$1"

	shName=$(echo "$name" | awk '{print tolower($0)}')
	find "${toolsPath}/launchers/" -maxdepth 1 -type f -iname "$shName.sh" -o -type f -iname "$shName-emu.sh" | \
	while read -r f
	do
		echo "deleting $f"
		rm -f "$f"
	done

    find "${EMUDECKGIT}/tools/launchers/" -type f -iname "$shName.sh" -o -type f -iname "$shName-emu.sh" | \
    while read -r l
    do
        echo "deploying $l"
        launcherFileName=$(basename "$l")
        chmod +x "$l"
        cp -v "$l" "${toolsPath}/launchers/"
        chmod +x "${toolsPath}/launchers/"*
    done


}

addSteamInputCustomIcons() {
	rsync -av "$EMUDECKGIT/configs/steam-input/Icons/" "$HOME/.steam/steam/tenfoot/resource/images/library/controller/binding_icons"
}

getEmuInstallStatus() {
	emuArray=(	"$@")
	installStatus=()
	for emu in "${emuArray[@]}"; do
		installStatus+=($("${emu}_IsInstalled"))
	done

	paste <(printf "%s\n" "${emuArray[@]}") <(printf "%s\n" "${installStatus[@]}") |
	jq -nR '{ Emulators: [inputs] | map(split("\t") | { Name: .[0], Installed: .[1] }) }'
}

isFpInstalled(){
	flatPakID=$1
	if (flatpak --columns=app list --user | grep -q "^$flatPakID$") || (flatpak --columns=app list --system | grep -q "^$flatPakID$"); then
		echo "true"
	else
		echo "false"
	fi
}

check_internet_connection(){
  ping -q -c 1 -W 1 8.8.8.8 > /dev/null 2>&1 && echo true || echo false
}

zipLogs() {
	local desktop=$(xdg-user-dir DESKTOP)

	logsFolder="$HOME/emudeck/logs"
	settingsFile="$HOME/emudeck/settings.sh"
	zipOutput="$desktop/emudeck_logs.zip"

	# Comprime los archivos en un archivo zip
	zip -rj "$zipOutput" "$logsFolder" "$settingsFile"

	if [ $? -eq 0 ]; then
		echo "true"
	else
		echo "false"
	fi
}

setResolutions(){
	Cemu_setResolution
	Citra_setResolution
	Dolphin_setResolution
	DuckStation_setResolution
	Flycast_setResolution
	MAME_setResolution
	melonDS_setResolution
	mGBA_setResolution
	PCSX2QT_setResolution
	PPSSPP_setResolution
	Primehack_setResolution
	RPCS3_setResolution
	Ryujinx_setResolution
	ScummVM_setResolution
	Vita3K_setResolution
	Xemu_setResolution
	Xenia_setResolution
	Yuzu_setResolution
}

# get variable value from kvp-style config file
# VAR1=VALUE1
# VAR2="VALUE 2"
# ...
scriptConfigFileGetVar() {
    local configFile=$1
    local configVar=$2
    local configVarDefaultValue=$3

    local configVarValue="$( (grep -E "^${configVar}=" -m 1 "${configFile}" 2>/dev/null || echo "_=__UNDEFINED__") | head -n 1 | cut -d '=' -f 2- | xargs )"
    if [ "${configVarValue}" = "__UNDEFINED__" ]; then
        configVarValue="${configVarDefaultValue}"
    fi

    printf -- "%s" "${configVarValue}"
}


getEmuRepo() {
	case "$1" in
		"cemu") repo="cemu-project/Cemu" ;;
		"citra") repo="citra-emu/citra-nightly" ;;
		"dolphin") repo="shiiion/dolphin" ;;
		"duckstation") repo="stenzek/duckstation" ;;
		"flycast") repo="flyinghead/flycast" ;;
		"MAME") repo="mamedev/mame" ;;
		"melonDS") repo="melonDS-emu/melonDS" ;;
		"mgba") repo="mgba-emu/mgba" ;;
		"pcsx2") repo="pcsx2/pcsx2" ;;
		"primehack") repo="shiiion/dolphin" ;;
		"rpcs3") repo="RPCS3/rpcs3-binaries-win" ;;
		"ryujinx") repo="Ryujinx/release-channel-master" ;;
		"vita3K") repo="Vita3K/Vita3K" ;;
		"xemu") repo="xemu-project/xemu" ;;
		"xenia") repo="xenia-canary/xenia-canary" ;;
		"yuzu") repo="yuzu-emu/yuzu-mainline" ;;
		*) repo="none" ;;
	esac
	echo "$repo"
}

getLatestVersionGH() {
	repository=$1
	url="https://api.github.com/repos/$repository/releases/latest"
	id=$(curl -s $url | jq -r '.id')
	echo $id
}

#!/bin/bash

saveLatestVersionGH() {
	emuName=$1
	repo=$(getEmuRepo "$emuName")

	if [ "$repo" == "none" ]; then
		echo "no autoupdate"
	else
		emuVersion=$(getLatestVersionGH "$repo")

		# JSON file path
		jsonFilePath="$HOME/emudeck/emu_versions.json"

		if [ -e "$jsonFilePath" ]; then
			echo "file found"
		else
			echo "{}" > "$jsonFilePath"
		fi

		# Read the content of the JSON file
		jsonContent=$(cat "$jsonFilePath" | jq -c '.')

		# Check if the key exists
		if [[ $(echo "$jsonContent" | jq -r ".$emuName") != "null" ]]; then
			# The key exists, change its value
			jsonContent=$(echo "$jsonContent" | jq ".$emuName=\"$emuVersion\"")
		else
			# The key doesn't exist, create it with a new value
			jsonContent=$(echo "$jsonContent" | jq ".$emuName=\"$emuVersion\"")
		fi

		# Save the modified JSON back to the file
		echo "$jsonContent" > "$jsonFilePath"
	fi
}

isLatestVersionGH() {
	emuName=$1
	dontUpdate="$HOME/emudeck/emulatorInit.noupdate"
	emuDontUpdate="${emuName}.noupdate"

	# check global noupdate file flag, emulator noupdate flag file using case insensitive find and internet connectivity
	if [ ! -f "${dontUpdate}" ] && [[ -z $(find "$HOME/emudeck/" -maxdepth 1 -type f -iname "${emuDontUpdate}") ]] && [ "$(check_internet_connection)" == "true" ]; then
		repo=$(getEmuRepo "$emuName")

		if [ "$repo" == "none" ]; then
			echo "no autoupdate"
		else
			emuVersion=$(getLatestVersionGH "$repo")

			# JSON file path
			jsonFilePath="$HOME/emudeck/emu_versions.json"

			if [ -f "$jsonFilePath" ]; then
				echo "file found"
			else
				echo "{}" > "$jsonFilePath"
			fi

			# Read the content of the JSON file
			jsonContent=$(cat "$jsonFilePath" | jq -c '.')

			# Check if the key exists
			if [[ $(echo "$jsonContent" | jq -r ".$emuName") != "null" ]]; then
				# The key exists, check if it's the same value
				if [ "$(echo "$jsonContent" | jq -r ".$emuName")" != "$emuVersion" ]; then
					jsonContent=$(echo "$jsonContent" | jq ".$emuName=\"$emuVersion\"")
					latest="false"
				else
					latest="true"
				fi
			else
				# The key doesn't exist, create it with a new value
				jsonContent=$(echo "$jsonContent" | jq ".$emuName=\"$emuVersion\"")
				latest="true"
			fi

			if [ "$latest" == "false" ]; then
				# Ask the user to update
				capitalizedEmuName="$(echo $emuName | awk '{print toupper(substr($1,1,1))tolower(substr($1,2))}')"
				zenity --question --title "New Update" --text "We've detected an update for $capitalizedEmuName. Do you want to update?" --ok-label "Yes" --cancel-label "No"
				if [ $? = 0 ]; then
					# Save the modified JSON back to the file
					echo "$jsonContent" > "$jsonFilePath"

					# Invocar la función de instalación dinámicamente
					"${capitalizedEmuName}_install"
					echo "${capitalizedEmuName}_install" > "$HOME/update.txt"
				fi
			else
				# Save the modified JSON back to the file
				echo "$jsonContent" > "$jsonFilePath"
			fi

			echo "Latest version=$latest"
		fi
	fi
}

addProtonLaunch(){
	rsync -avhp "$EMUDECKGIT/tools/proton-launch.sh" "${toolsPath}"
	rsync -avhp "$EMUDECKGIT/tools/appID.py" "${toolsPath}"
	chmod +x "${toolsPath}/proton-launch.sh"
}

function emulatorInit(){
	local emuName=$1
	#isLatestVersionGH "$emuName"
	#NetPlay
	if [ "$emuName" = 'retroarch' ]; then
   		if [ "$netPlay" == "true" ]; then
			#Looks for devices listening
			setSetting netplayCMD "-H"
			sleep 2
			netplaySetIP
		else
			setSetting netplayCMD "' '"
			cloud_sync_downloadEmu "$emuName" && cloud_sync_startService
		fi
		source $HOME/.config/EmuDeck/backend/functions/all.sh
	fi

	if [ "$emuName" != 'retroarch' ]; then
		cloud_sync_downloadEmu "$emuName" && cloud_sync_startService
	fi
}

function jsonToBashVars(){
	local json=$1
	echo "#!/bin/bash" > "$emuDecksettingsFile"
	#Install Emus
	setSetting system "$(jq .system $json)"
	setSetting doInstallRA "$(jq .installEmus.ra.status $json)"
	setSetting doInstallDolphin "$(jq .installEmus.dolphin.status $json)"
	setSetting doInstallPCSX2QT "$(jq .installEmus.pcsx2.status $json)"
	setSetting doInstallRPCS3 "$(jq .installEmus.rpcs3.status $json)"
	setSetting doInstallYuzu "$(jq .installEmus.yuzu.status $json)"
	setSetting doInstallSuyu "$(jq .installEmus.suyu.status $json)"
	setSetting doInstallCitra "$(jq .installEmus.citra.status $json)"
	setSetting doInstallDuck "$(jq .installEmus.duckstation.status $json)"
	setSetting doInstallCemu "$(jq .installEmus.cemu.status $json)"
	setSetting doInstallXenia "$(jq .installEmus.xenia.status $json)"
	setSetting doInstallRyujinx "$(jq .installEmus.ryujinx.status $json)"
	setSetting doInstallMAME "$(jq .installEmus.mame.status $json)"
	setSetting doInstallPrimeHack "$(jq .installEmus.primehack.status $json)"
	setSetting doInstallPPSSPP "$(jq .installEmus.ppsspp.status $json)"
	setSetting doInstallXemu "$(jq .installEmus.xemu.status $json)"
	setSetting doInstallSRM "$(jq .installEmus.srm.status $json)"
	setSetting doInstallmelonDS "$(jq .installEmus.melonds.status $json)"
	setSetting doInstallScummVM "$(jq .installEmus.scummvm.status $json)"
	setSetting doInstallFlycast "$(jq .installEmus.flycast.status $json)"
	setSetting doInstallVita3K "$(jq .installEmus.vita3k.status $json)"
	setSetting doInstallMGBA "$(jq .installEmus.mgba.status $json)"
	setSetting doInstallPrimehack "$(jq .installEmus.primehack.status $json)"
	setSetting doInstallRMG "$(jq .installEmus.rmg.status $json)"
	setSetting doInstallares "$(jq .installEmus.ares.status $json)"
	setSetting doInstallSupermodel "$(jq .installEmus.supermodel.status $json)"
	setSetting doInstallModel2  "$(jq .installEmus.model2.status $json)"
	setSetting doInstallBigPEmu  "$(jq .installEmus.bigpemu.status $json)"


	#Setup Emus
	setSetting doSetupRA $(jq .overwriteConfigEmus.ra.status "$json")
	setSetting doSetupDolphin "$(jq .overwriteConfigEmus.dolphin.status $json)"
	setSetting doSetupPCSX2QT "$(jq .overwriteConfigEmus.pcsx2.status $json)"
	setSetting doSetupRPCS3 "$(jq .overwriteConfigEmus.rpcs3.status $json)"
	setSetting doSetupYuzu "$(jq .overwriteConfigEmus.yuzu.status $json)"
	setSetting doSetupSuyu "$(jq .overwriteConfigEmus.suyu.status $json)"
	setSetting doSetupCitra "$(jq .overwriteConfigEmus.citra.status $json)"
	setSetting doSetupDuck "$(jq .overwriteConfigEmus.duckstation.status $json)"
	setSetting doSetupCemu "$(jq .overwriteConfigEmus.cemu.status $json)"
	setSetting doSetupXenia "$(jq .overwriteConfigEmus.xenia.status $json)"
	setSetting doSetupRyujinx "$(jq .overwriteConfigEmus.ryujinx.status $json)"
	setSetting doSetupMAME "$(jq .overwriteConfigEmus.mame.status $json)"
	setSetting doSetupPrimeHack "$(jq .overwriteConfigEmus.primehack.status $json)"
	setSetting doSetupPPSSPP "$(jq .overwriteConfigEmus.ppsspp.status $json)"
	setSetting doSetupXemu "$(jq .overwriteConfigEmus.xemu.status $json)"
	setSetting doSetupSRM "$(jq .overwriteConfigEmus.srm.status $json)"
	setSetting doSetupmelonDS "$(jq .overwriteConfigEmus.melonds.status $json)"
	setSetting doSetupScummVM "$(jq .overwriteConfigEmus.scummvm.status $json)"
	setSetting doSetupFlycast "$(jq .overwriteConfigEmus.flycast.status $json)"
	setSetting doSetupVita3K "$(jq .overwriteConfigEmus.vita3k.status $json)"
	setSetting doSetupMGBA "$(jq .overwriteConfigEmus.mgba.status $json)"
	setSetting doSetupPrimehack "$(jq .overwriteConfigEmus.primehack.status $json)"
	setSetting doSetupRMG "$(jq .overwriteConfigEmus.rmg.status $json)"
	setSetting doSetupares "$(jq .overwriteConfigEmus.ares.status $json)"
	setSetting doSetupSupermodel "$(jq .overwriteConfigEmus.supermodel.status $json)"
	setSetting doSetupModel2 "$(jq .overwriteConfigEmus.model2.status $json)"
	setSetting doSetupBigPEmu  "$(jq .overwriteConfigEmus.bigpemu.status $json)"

	#Frontends
	setSetting doSetupSRM "$(jq .overwriteConfigEmus.srm.status $json)"
	setSetting doSetupESDE "$(jq .overwriteConfigEmus.esde.status $json)"
	setSetting doInstallESDE "$(jq .installFrontends.esde.status $json)"
	setSetting doInstallPegasus "$(jq .installFrontends.pegasus.status $json)"
	setSetting steamAsFrontend "$(jq .installFrontends.steam.status $json)"


	#Customizations
	setSetting RABezels "$(jq .bezels $json)"
	setSetting RAautoSave "$(jq .autosave $json)"
	setSetting arClassic3D "$(jq .ar.classic3d $json)"
	setSetting arDolphin "$(jq .ar.dolphin $json)"
	setSetting arSega "$(jq .ar.sega $json)"
	setSetting arSnes "$(jq .ar.snes $json)"
	setSetting RAHandClassic2D "$(jq .shaders.classic $json)"
	setSetting RAHandClassic3D "$(jq .shaders.classic3d $json)"
	setSetting RAHandHeldShader "$(jq .shaders.handhelds $json)"
	setSetting controllerLayout "$(jq .controllerLayout $json)"

	#CloudSync
	setSetting cloud_sync_provider "$(jq .cloudSync $json)"
	setSetting cloud_sync_status "$(jq .cloudSyncStatus $json)"

	#Resolutions
	setSetting dolphinResolution  "$(jq .resolutions.dolphin $json)"
	setSetting duckstationResolution  "$(jq .resolutions.duckstation $json)"
	setSetting pcsx2Resolution  "$(jq .resolutions.pcsx2 $json)"
	setSetting yuzuResolution  "$(jq .resolutions.yuzu $json)"
	setSetting ppssppResolution  "$(jq .resolutions.ppsspp $json)"
	setSetting rpcs3Resolution  "$(jq .resolutions.rpcs3 $json)"
	setSetting citraResolution  "$(jq .resolutions.citra $json)"
	setSetting xemuResolution  "$(jq .resolutions.xemu $json)"
	setSetting xeniaResolution  "$(jq .resolutions.xenia $json)"
	setSetting melondsResolution  "$(jq .resolutions.melonds $json)"

	#MultiEmu Parsers
	setSetting emuGBA  "$(jq .emulatorAlternative.gba $json)"
	setSetting emuMAME  "$(jq .emulatorAlternative.mame $json)"
	setSetting emuMULTI  "$(jq .emulatorAlternative.multiemulator $json)"
	setSetting emuN64  "$(jq .emulatorAlternative.n64 $json)"
	setSetting emuNDS  "$(jq .emulatorAlternative.nds $json)"
	setSetting emuPSP  "$(jq .emulatorAlternative.psp $json)"
	setSetting emuPSX  "$(jq .emulatorAlternative.psx $json)"
	setSetting emuDreamcast  "$(jq .emulatorAlternative.dreamcast $json)"
	setSetting emuSCUMMVM "$(jq .emulatorAlternative.scummvm $json)"

	#Paths
	globPath=$(jq .storagePath $json)
	setSetting emulationPath "$globPath/Emulation"
	setSetting romsPath "$globPath/Emulation/roms"
	setSetting toolsPath "$globPath/Emulation/tools"
	setSetting biosPath "$globPath/Emulation/bios"
	setSetting savesPath "$globPath/Emulation/saves"
	setSetting storagePath "$globPath/Emulation/storage"
	setSetting ESDEscrapData "$globPath/Emulation/tools/downloaded_media"

	#Default ESDE Theme
	setSetting esdeThemeUrl "$(jq .themeESDE[0] $json)"
	setSetting esdeThemeName "$(jq .themeESDE[1] $json)"

	#Default Pegasus Theme
	setSetting pegasusThemeUrl "$(jq .themePegasus[0] $json)"
	setSetting pegasusThemeName "$(jq .themePegasus[1] $json)"

	#RetroAchiviements
	setSetting achievementsUser "$(jq .achievements.user $json)"
	setSetting achievementsUserToken "$(jq .achievements.token $json)"
	setSetting achievementsHardcore "$(jq .achievements.hardcore $json)"

	#Android
	setSetting androidStorage "$(jq .android.storage $json)"
	setSetting androidStoragePath "$(jq .android.storagePath $json)"

	#We store the patreon token on install so we can create it for the first time
	storePatreonToken "$(jq .patreonToken $json)"
}

function storePatreonToken(){
	local token=$1
	echo "$token" > "$savesPath/.token"
	if [ -f $cloud_sync_bin ]; then
		"$cloud_sync_bin"  --progress copyto -L --fast-list --checkers=50 --transfers=50 --low-level-retries 1 --retries 1 "$savesPath/.token" "$cloud_sync_provider":Emudeck/saves/.token
	fi
}


function controllerLayout_ABXY(){
	Dolphin_setABXYstyle
	Cemu_setABXYstyle
	Ryujinx_setABXYstyle
	RetroArch_setABXYstyle
	melonDS_setABXYstyle
	RMG_setABXYstyle
}

function controllerLayout_BAYX(){
	Dolphin_setBAYXstyle
	Cemu_setBAYXstyle
	Ryujinx_setBAYXstyle
	RetroArch_setBAYXstyle
	melonDS_setBAYXstyle
	RMG_setBAYXstyle
}
