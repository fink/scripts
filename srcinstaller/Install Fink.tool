#!/bin/bash

# Config
OSXVersion="$(sw_vers -productVersion | cut -f -2 -d .)"
DarwinVersion="$(uname -a | cut -d' ' -f3)"
XcodeURL="macappstore://itunes.apple.com/us/app/xcode/id497799835?mt=12"

Jvers="1.6"

FinkVersion="0.38.6"
FinkMD5Sum="dd5875fc96d10e782a63b17c837c8e1c"
FinkOutDir="fink"
FinkDirectorY="${FinkOutDir}-${FinkVersion}"
FinkFileName="${FinkDirectorY}.tar.gz"
FinkSourceDLP="http://downloads.sourceforge.net/fink/${FinkFileName}"

XQuartzVersion="2.7.7"
XQuartzMD5Sum="0da81910acfa33c2d9663deb0c8c98f7"
XQuartzPKGPath="XQuartz.pkg"
XQuartzFileName="XQuartz-${XQuartzVersion}.dmg"
XQuartzSourceDLP="http://xquartz.macosforge.org/downloads/SL/${XQuartzFileName}"


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
		if ! curl -Lfo "${FileName}" --connect-timeout "30" "${SourceDLP}"; then
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
if [[ "${DarwinVersion}" < "13" ]]; then
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
will atempt to install it for you; in most cases this will mean the
script will exit while it waits for the install to finish. After an
install has completed just run this script again and it will pick up
where it left off.

EOF

# Handle existing installs
if [ -d "/sw" ]; then
	FinkExisting="1"
	cat > "/dev/stderr" << EOF
It looks like you already have fink installed; if it did not finish or
you are upgrading we will move it aside to /sw.old so you can delete it
later if you like; otherwise you may want to exit.

EOF
fi

if ! read -n1 -rsp $'Press any key to continue or ctrl+c to exit.\n'; then
	exit 1
fi

if [ "${FinkExisting}" = "1" ]; then
	if ! sudo mv /sw /sw.old; then
		clear
		cat > "/dev/stderr" << EOF
Could not move /sw to /sw.old; you may need to delete one or both these
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
	sudo xcode-select -switch "${XcodePath}/Contents/Developer"
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
	java -version 2>&1>/dev/null
	echo "Please install the JDK not the JRE, since we need it to build things against; please rerun this script when it finishes installing." >&2
	exit 0
fi
echo "Found version $(java -version 2>&1>/dev/null | grep 'version' | sed -e 's:java version ::' -e 's:"::g')." >&2

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
if ! pkgutil --pkg-info=org.macosforge.xquartz.pkg; then
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
clear
read -rp $'Do you want to use the binary distribution instead of having to build all packages locally?\n[Y|n] ' choice
if [[ "${choice}" = "y" ]] || [[ "${choice}" = "Y" ]] || [[ -z "${choice}" ]]; then
	UseBinaryDist="1"
fi

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

if ! ./bootstrap /sw; then 
	exit 1
fi

# Set up bindist
if [ "${UseBinaryDist}" = "1" ]; then
	clear
	echo "Activating the Binary Distribution..." >&2
	sudo rm /sw/etc/fink.conf.bak
	sudo mv /sw/etc/fink.conf /sw/etc/fink.conf.bak
	sed -e 's|UseBinaryDist: false|UseBinaryDist: true|' "/sw/etc/fink.conf.bak" | sudo tee "/sw/etc/fink.conf"
fi

if ! grep -Fqx 'http://bindist.finkproject.org/' "/sw/etc/apt/sources.list"; then
	sudo tee -a "/sw/etc/apt/sources.list" << EOF

# Official bindist see http://bindist.finkmirrors.net/ for details.
deb http://bindist.finkproject.org/${OSXVersion} stable main

EOF
fi

# Set up paths
clear
echo "Setting up Fink paths..." >&2
/sw/bin/pathsetup.sh

# First selfupdate
source /sw/bin/init.sh
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
