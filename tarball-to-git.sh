#!/bin/bash
# -----------------------------------------------------------------------------
# tarball-to-git.sh
#
# This script will add the contents of the ADOdb release tarballs as downloaded
# from sourceforge [1] and create a new commit in the git repository for each
#
# Params
#   $1  (optional) location of tarballs, defaults to /tmp
#
# 2012-06-29  dregad  created
# 2012-09-05  dregad  modified to work directly from tarballs
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Settings
#

# Default location of the downloaded ADOdb tarballs
source=/tmp

# ADOdb file prefix + directory containing the ADOdb library within the repo
target=adodb5

# Git repository branch for upstream
upstream=master

# -----------------------------------------------------------------------------
# Init
#

# Get the tarballs to process (from command line or default dir)
filespec="$target*"
if [ -n "$1" ]
then
	if [ -d "$1" ]
	then
		source=$1
	else
		source=$(dirname $1)
		filespec=$(basename $1)
		if [ ! -r "$1" ]
		then
			if [ $(ls $1* 2>/dev/null |wc -l) -gt 0 ]
			then
				filespec="$filespec*"
			else
				echo "ERROR: source directory for ADOdb tarballs '$1' not found"
				exit 1
			fi
		fi
	fi
fi

pushd $source >/dev/null
source=$PWD
list=$(find . -maxdepth 1 -name "$filespec" -type f |cut -d/ -f2 |sort)
popd >/dev/null
if [ -z "$list" ]
then
	echo "No ADOdb tarballs available in '$source' - nothing to do"
	exit 0
fi

echo "The following files will be processed

$list

Press enter to continue or CTRL-C to abort"
read

cd $(dirname $0)
git co $upstream >/dev/null 2>&1


# -----------------------------------------------------------------------------
# Main
#

# Initial import: reset git repo to first commit
# git reset --hard 654e80bbd697dd72d36967092956adf52da2ac1e
# git tag -d $(git tag)

for tarball in $list
do
	echo -n "Processing $tarball... "

	ext=${tarball: -3}
	ver=5.$(basename ${tarball#$target} .$ext)

	# Removing previous version's files from the repository
	rm -rf $target

	# Extract the files from archive
	case $ext
	in
		'tgz' )
			tar -xzf $source/$tarball
			;;

		'zip' )
			unzip -q $source/$tarball
			;;

		* )
			echo
			echo "ERROR: unknown file type "
			exit 1
	esac

	# Version release date (special cases where date not updated in adodb.inc.php)
	case $ver
	in
		'5.01beta' )
			vdate='17 May 2007'
			ver='5.01beta'
			;;

		* )
			vdate=$(sed -rn "/@version/ s/^.*5\.[0-9a]* (.*) *\(c\).*$/\1/p" $target/adodb.inc.php)
			;;
	esac

	echo "Version $ver released $vdate"

	# Check if version has already been added
	git tag -l |grep  "v$ver" >/dev/null
	if [ $? -eq 0 ]
	then
		echo "WARNING: a tag for this version already exists in the repository, skipping"
		echo
		continue
	fi

	# Commit message
	msg1="ADOdb version $ver"
	msg2="Released $vdate"

	# Updating git (adding new/modified files, removing deleted ones), commit and tag

	# Add all new files
	git add .

	# Any remaining unstaged files are not in the new version and should be deleted
	IFS=$'\n'
	remove=$(git diff --name-only)
	if [ -n "$remove" ]
	then
		git rm --  $remove
	fi
	unset IFS

	# Commit and tag
	git commit -m "$(echo -e "$msg1\n\n$msg2")"
	git tag -f -m "$msg1 - $msg2" 	v$ver

	echo
done

