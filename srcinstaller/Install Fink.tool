#!/bin/bash
# shellcheck disable=SC2155
# shellcheck disable=SC2164
# shellcheck disable=SC1091
# shellcheck disable=SC1117
# shellcheck disable=SC2236


# Config
OSXVersion="$(sw_vers -productVersion | cut -f -2 -d .)"
DarwinVersion="$(uname -r | cut -d. -f1)"
XcodeURL="macappstore://itunes.apple.com/us/app/xcode/id497799835?mt=12"

# Starting with 10.15 we do not use /sw due to SIP.
if [ "${DarwinVersion}" -le "18" ]; then 
	FinkPrefix="/sw"
else
	FinkPrefix="/opt/sw"
fi

# Java site: https://jdk.java.net/
Jvers="1.6"
JavaVersion="15.0.2"
JavaMD5Sum="e60e98233fb2dea42ca53825e73355cd"
JavaOutDir="jdk-${JavaVersion}.jdk"
JavaDirectorY="${JavaOutDir}"
JavaFileName="openjdk-${JavaVersion}_osx-x64_bin.tar.gz"
JavaSourceDLP="https://download.java.net/java/GA/jdk${JavaVersion}/0d1cfde4252546c6931946de8db48ee2/7/GPL/${JavaFileName}"

FinkVersion="0.45.4"
FinkMD5Sum="d5460fe6834f82f173d6f95ea0ec1bf8"
FinkOutDir="fink"
FinkDirectorY="${FinkOutDir}-${FinkVersion}"
FinkFileName="${FinkDirectorY}.tar.gz"
FinkSourceDLP="https://downloads.sourceforge.net/project/fink/fink/${FinkVersion}/${FinkFileName}"

XQuartzVersion="2.8.1"
XQuartzMD5Sum="40802a3bbd5ec72e96affd94be567680"
XQuartzPKGPath="XQuartz.pkg"
XQuartzFileName="XQuartz-${XQuartzVersion}.dmg"
XQuartzSourceDLP="https://github.com/XQuartz/XQuartz/releases/download/XQuartz-${XQuartzVersion}/${XQuartzFileName}"


function fetchBin {

	local MD5Sum="$1"
	local SourceDLP="$2"
	local FileName="$3"
	local DirectorY="$4"
	local OutDir="$5"

	# Checks
	if [[ -d "${OutDir}" ]] && [[ -f "${FileName}" ]]; then
		# Check to make sure we have the right file
		local MD5SumLoc="$(cat "${OutDir}/.MD5SumLoc" 2>/dev/null || echo "")"
		if [ "${MD5SumLoc}" != "${MD5Sum}" ]; then
			echo "warning: Cached file is outdated or incorrect, removing" >&2
			rm -fR "${DirectorY}" "${OutDir}"
			MD5SumFle="$(md5 -q "${FileName}")"
			if [ "${MD5SumFle}" != "${MD5Sum}" ]; then
				rm -fR "${FileName}"
			fi
		else
			# Do not do more work then we have to
			echo "${OutDir} already exists, skipping" >&2
			return
		fi
	elif [[ -f "${FileName}" ]]; then
		MD5SumFle="$(md5 -q "${FileName}")"
		if [ "${MD5SumFle}" != "${MD5Sum}" ]; then
			rm -fR "${FileName}"
		fi
	fi

	# Fetch
	if [ ! -r "${FileName}" ]; then
		echo "Fetching ${SourceDLP}"
		if ! curl -Lfo "${FileName}" --connect-timeout "30" -H 'referer:' -A "fink/${FinkVersion}" "${SourceDLP}"; then
			echo "error: Unable to fetch ${SourceDLP}" >&2
			exit 1
		fi
	else
		echo "${FileName} already exists, skipping" >&2
	fi

	# Check our sums
	local MD5SumLoc="$(md5 -q "${FileName}")"
	if [ -z "${MD5SumLoc}" ]; then
		echo "error: Unable to compute md5 for ${FileName}" >&2
		exit 1
	elif [ "${MD5SumLoc}" != "${MD5Sum}" ]; then
		echo "error: MD5 does not match for ${FileName}" >&2
		exit 1
	fi

	# Unpack
	local ExtensioN="${FileName##*.}"
	if [[ "${ExtensioN}" = "gz" ]] || [[ "${ExtensioN}" = "tgz" ]]; then
		if ! tar -zxf "${FileName}"; then
			echo "error: Unpacking ${FileName} failed" >&2
			exit 1
		fi
	elif [ "${ExtensioN}" = "bz2" ]; then
		if ! tar -jxf "${FileName}"; then
			echo "error: Unpacking ${FileName} failed" >&2
			exit 1
		fi
	elif [ "${ExtensioN}" = "dmg" ]; then
		return
	else
		echo "error: Unable to unpack ${FileName}" >&2
		exit 1
	fi

	# Save the sum
	echo "${MD5SumLoc}" > "${DirectorY}/.MD5SumLoc"

	# Move
	if [ ! -d "${DirectorY}" ]; then
		echo "error: Can't find ${DirectorY} to rename" >&2
		exit 1
	else
		mv "${DirectorY}" "${OutDir}"
	fi
}

# Make sure we are in the right place
cd "${HOME}/Downloads"

# Version check
if [[ "${DarwinVersion}" -lt "13" ]]; then
	echo "This script is for use on OS 10.9+ only."
	exit 1
fi

# Intro Explanation
cat > "/dev/stderr" << EOF
This script will automate the installation of fink, its prerequisets
and help out a bit with initial setup; to do this an internet
connection is required.

Before fink can be installed you need to have java, the Command Line
Tools, XQuartz and accepted the xcode licence. Additionally you may
wish to install the full Xcode app.

After this script detects one of these requirements to be missing it
will attempt to install it for you; in most cases this will mean the
script will exit while it waits for the install to finish. After an
install has completed just run this script again and it will pick up
where it left off.

EOF

# Handle existing installs
if [ -d "${FinkPrefix}" ]; then
	FinkExisting="1"
	cat > "/dev/stderr" << EOF
It looks like you already have fink installed; if it did not finish or
you are upgrading we will move it aside to ${FinkPrefix}.old so you can delete it
later if you like; otherwise you may want to exit.

EOF
fi

if ! read -n1 -rsp $'Press any key to continue or ctrl+c to exit.\n'; then
	exit 1
fi

if [ "${FinkExisting}" = "1" ]; then
	if ! sudo mv "${FinkPrefix}" "${FinkPrefix}.old"; then
		clear
		cat > "/dev/stderr" << EOF
Could not move ${FinkPrefix} to ${FinkPrefix}.old; you may need to delete one or both these
yourself.
EOF
		exit 1
	fi
fi


# Check for Xcode
clear
echo "Checking to see if xcode is installed..." >&2
XcodePath="$(mdfind kMDItemCFBundleIdentifier = "com.apple.dt.Xcode")"
if [ ! -z "${XcodePath}" ]; then
	echo "Xcode is installed, setting up the defaults..." >&2
	sudo xcode-select --switch "${XcodePath}/Contents/Developer"
else
	echo "You do not have Xcode installed." >&2
	read -rp $'Do you want to install xcode?\n[N|y] ' choice
	if [[ "${choice}" = "y" ]] || [[ "${choice}" = "Y" ]]; then
		open "${XcodeURL}"
		exit 0
	fi
fi

# Check for java
clear
echo "Checking for Java..." >&2
if ! /usr/libexec/java_home -Fv "${Jvers}+"; then
	java -version > /dev/null 2>&1
	echo "JDK is not installed, fetching..." >&2
	fetchBin "${JavaMD5Sum}" "${JavaSourceDLP}" "${JavaFileName}" "${JavaDirectorY}" "${JavaOutDir}"
	if [ ! -d "/Library/Java/JavaVirtualMachines" ]; then
		sudo install -d -o "root" -g "wheel" "/Library/Java/JavaVirtualMachines"
	fi
	sudo mv "${JavaOutDir}" "/Library/Java/JavaVirtualMachines/"
	sudo chown -R root:wheel "/Library/Java/JavaVirtualMachines/${JavaOutDir}"
	sudo rm "/Library/Java/JavaVirtualMachines/${JavaOutDir}/.MD5SumLoc"
fi
echo "Found version $(java -version 2>&1 | grep 'version' | sed -e 's:java version ::' -e 's:openjdk version ::')." >&2

# Check for Command Line Tools
clear
echo "Checking for the Xcode Command Line Tools..." >&2
if ! pkgutil --pkg-info=com.apple.pkg.CLTools_Executables; then
	echo "The Xcode Command Line Tools are installing, please rerun when it finishes." >&2
	xcode-select --install
	exit 0
fi

# Check for XQuartz
clear
echo "Checking for XQuartz..." >&2
if ! pkgutil --pkg-info=org.xquartz.X11; then
	echo "XQuartz is not installed, fetching..." >&2
	fetchBin "${XQuartzMD5Sum}" "${XQuartzSourceDLP}" "${XQuartzFileName}" "-" "-"
	echo "Mounting the XQuartz disk..." >&2
	hdiutilOut="$(hdiutil mount "${XQuartzFileName}" 2>/dev/null | tr -d "\t" | grep -F '/dev/disk' | grep -Fv 'GUID_partition_scheme')"
	XQuartzVolPath="$(echo "${hdiutilOut}" | sed -E 's:(/dev/disk[0-9])(s[0-9])?( +)?(Apple_HFS)?( +)::')"
	echo "Starting the XQuartz install; please rerun this script when it finishes." >&2
	open "${XQuartzVolPath}/${XQuartzPKGPath}"
	exit 0
fi

# Check the xcode licence
if [[ ! -f /Library/Preferences/com.apple.dt.Xcode.plist ]] && [[ ! -z "${XcodePath}" ]]; then
	choice=""
	while [[ ! "${choice}" = "1" ]] || [[ ! "${choice}" = "2" ]] || [[ ! "${choice}" = "3" ]]; do
		clear
		cat > "/dev/stderr" << EOF
You need to accept the xcode licence to continue.
You can:
[1] Read the licence and accept it. (Default)
[2] Accept the licence without reading it.
[3] Quit.
EOF
		read -rp $'[1|2|3] ' choice
		if [ -z "${choice}" ]; then
			choice="1"
		fi
		case "${choice}" in
			1) sudo xcodebuild -license ;;
			2) sudo xcodebuild -license accept ;;
			3) exit 0 ;;
			*) echo "Not a valid choice." >&2 ;;
		esac
	done
fi

# Get Fink
clear
echo "Fetching Fink..." >&2
fetchBin "${FinkMD5Sum}" "${FinkSourceDLP}" "${FinkFileName}" "${FinkDirectorY}" "${FinkOutDir}"
# clear
# read -rp $'Do you want to use the binary distribution instead of having to build all packages locally?\n[Y|n] ' choice
# if [[ "${choice}" = "y" ]] || [[ "${choice}" = "Y" ]] || [[ -z "${choice}" ]]; then
# 	UseBinaryDist="1"
# fi

# Build Fink
clear
cat > "/dev/stderr" << EOF
We are about to start building Fink; this may take a bit, so feel free
to grab a cup of you favorite beverage while you wait.
EOF

if ! read -n1 -rsp $'Press any key to continue or ctrl+c to exit.\n'; then
	exit 1
fi

clear
cd "${FinkOutDir}"

if ! ./bootstrap "${FinkPrefix}"; then
	exit 1
fi

# Set up bindist
# shellcheck disable=SC2154
if [ "${UseBinaryDist}" = "1" ]; then
	clear
	echo "Activating the Binary Distribution..." >&2
	sudo rm "${FinkPrefix}/etc/fink.conf.bak"
	sudo mv "${FinkPrefix}/etc/fink.conf" "${FinkPrefix}/etc/fink.conf.bak"
	sed -e 's|UseBinaryDist: false|UseBinaryDist: true|' "${FinkPrefix}/etc/fink.conf.bak" | sudo tee "${FinkPrefix}/etc/fink.conf"

	if grep -Fqx 'bindist.finkmirrors.net' "${FinkPrefix}/etc/apt/sources.list"; then
		# Fix wrong address.
		sudo rm "${FinkPrefix}/etc/apt/sources.list.finkbak"
		sudo mv "${FinkPrefix}/etc/apt/sources.list" "${FinkPrefix}/etc/apt/sources.list.finkbak"
		sed -e 's:finkmirrors.net:finkproject.org:g' "${FinkPrefix}/etc/apt/sources.list.finkbak" | sudo tee "${FinkPrefix}/etc/apt/sources.list"
	elif ! grep -Fqx 'http://bindist.finkproject.org/' "${FinkPrefix}/etc/apt/sources.list"; then
		sudo tee -a "${FinkPrefix}/etc/apt/sources.list" << EOF

# Official bindist see http://bindist.finkproject.org/ for details.
deb http://bindist.finkproject.org/${OSXVersion} stable main

EOF
	fi
fi

# Set up paths
clear
echo "Setting up Fink paths..." >&2
${FinkPrefix}/bin/pathsetup.sh

# First selfupdate
source ${FinkPrefix}/bin/init.sh
clear
cat > "/dev/stderr" << EOF
Now the last thing we will do is run 'fink selfupdate' for the first
time.

It will ask you to choose a method; unless you have a really picky
firewall you probaly want to choose rsync.

EOF

if ! read -n1 -rsp $'Press any key to continue or ctrl+c to exit.\n'; then
	exit 1
fi

fink selfupdate

exit 0
