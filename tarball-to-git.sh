#!/bin/bash

source=adodb-tarball
target=adodb

# -----------------------------------------------------------------------------

list=$(find $source/ -maxdepth 1 -type d |cut -d'/' -f2 |sort)

source=$PWD/$source
cd $target
target=adodb5

# Clean slate
git co master
git reset --hard 654e80bbd697dd72d36967092956adf52da2ac1e
git tag -d $(git tag)

for dir in $list
do
	ver=$(echo $dir |sed -r "s/^adodb(.)(.*)/\1.\2/")

	# Version release date (special cases where date not updated in adodb.inc.php)
	case $ver
	in
		'5.01beta' )
			vdate='17 May 2007'
			;;

		* )
			vdate=$(sed -rn "/@version/ s/^.*5\.[0-9a]* (.*) *\(c\).*$/\1/p" $source/$dir/adodb.inc.php)
			;;
	esac

	# Commit message
	msg1="ADOdb version $ver"
	msg2="Released $vdate"

	echo "Processing $ver ($dir) $vdate"

	echo "Removing previous version"
	rm -rf $target

	echo "Copying new version to $PWD"
	mkdir $target
	cp -r $source/$dir/* $target

	echo "Updating git (adding new/modified files, removing deleted ones), commit and tag"
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

