#!/bin/bash

# Config
OSXVersion="$(sw_vers -productVersion | cut -f -2 -d .)"
XcodeURL="https://itunes.apple.com/us/app/xcode/id497799835?mt=12"

FinkVersion="0.36.3.1"
FinkMD5Sum="0f16f23cba24ab2d7421cc3008b2efe2"
FinkOutDir="fink"
FinkDirectorY="${FinkOutDir}-${FinkVersion}"
FinkFileName="${FinkDirectorY}.tar.gz"
FinkSourceDLP="http://downloads.sourceforge.net/fink/${FinkFileName}"

XQuartzVersion="2.7.5"
XQuartzMD5Sum="8d44b11eb2e6948a3982408d7ecee043"
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
	local ExtensioN="$(echo "${FileName}" | sed -e 's:^.*\.\([^.]*\):\1:')"
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
cd "~/Downloads"


# Check for Xcode
XcodePath="$(osascript -e 'POSIX path of (path to application id "com.apple.dt.Xcode")' 2>/dev/null; osascript -e 'tell app id "com.apple.dt.Xcode" to quit' 2>/dev/null)"
if [ ! -z "${XcodePath}" ]; then
	sudo xcode-select -switch "${XcodePath}Contents/Developer"
else
	echo "You may want to install Xcode"
fi

# Check for java
if ! pkgutil --pkg-info=com.apple.pkg.JavaEssentials; then
	VJava="$(java -version 2>&1>/dev/null)"
	if [ "${VJava}" = "No Java runtime present, requesting install." ]; then
		exit 0
	fi
fi

# Check for Command Line Tools
if ! pkgutil --pkg-info=com.apple.pkg.CLTools_Executables; then
	xcode-select --install
	exit 0
fi

# Check for XQuartz
if ! pkgutil --pkg-info=org.macosforge.xquartz.pkg; then

	fetchBin "${XQuartzMD5Sum}" "${XQuartzSourceDLP}" "${XQuartzFileName}" "-" "-"
	hdiutilOut="$(hdiutil mount "${XQuartzFileName}" | tr -d "\t")"
	XQuartzVolPath="$(echo "${hdiutilOut}" | sed -E 's:(/dev/disk[0-9])( +)::')"
	open "${XQuartzVolPath}/${XQuartzPKGPath}"
	exit 0
fi

# Check the xcode licence
if [[ ! -f /Library/Preferences/com.apple.dt.Xcode.plist ]]; then
	sudo xcodebuild -license accept
if

# Get Fink
fetchBin "${FinkMD5Sum}" "${FinkSourceDLP}" "${FinkFileName}" "${FinkDirectorY}" "${FinkOutDir}"

# Build Fink
cd "${FinkOutDir}"

if ! ./bootstrap /sw; then 
	exit 1
fi

# Set up bindist
sudo rm /sw/etc/fink.conf.bak
sudo mv /sw/etc/fink.conf /sw/etc/fink.conf.bak
sudo sed -e 's|UseBinaryDist: false|UseBinaryDist: true|' "/sw/etc/fink.conf.bak" > "/sw/etc/fink.conf"

sudo cat >> "/sw/etc/apt/sources.list" << EOF

# Official bindist see http://bindist.finkmirrors.net/ for details.
deb http://bindist.finkproject.org/${OSXVersion} stable main

EOF

# Set up paths
/sw/bin/pathsetup.sh
