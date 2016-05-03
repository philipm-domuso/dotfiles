#!/usr/bin/env bash
TEST=false
VERBOSE=false
OVERRIDE=false

for i in "$@" ; do
	case $i in
		"-t"|"--test")
			TEST=true
			;;
		"-v"|"--verbose")
			VERBOSE=true
			;;
		"-o"|"--override")
			OVERRIDE=true
			;;
		*)
			;;
	esac
	shift
done
function get_abs_filename() {
  # $1 : relative filename
  if [ -d "$(dirname "$1")" ]; then
    echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  fi
}
function linking_me_softly() {
	# $1 = source, $2 = destination
	real_source=$(get_abs_filename $1)
	[[ $VERBOSE == true || $TEST == true ]] && echo "Link: $real_source => $2"
	if [[ -e $2 ]] ; then
		if [[ $OVERRIDE == false ]] ; then
			[[ $VERBOSE == true ]] && echo "Skipping: $2 already exists."
			return
		fi
	fi	
	if [ $TEST == true ] ; then
		return
	fi
	ln -sf $real_source $2
}

# init the submodules
[[ $VERBOSE == true || $TEST == true ]] && echo "Updating git submodules."
if [[ $TEST == false ]] ; then
	git submodule update --init
	git submodule update --recursive --remote
fi

for directory in $(ls -d */) ; do
	dir=${directory%%/}
	[[ $VERBOSE == true ]] && echo "Handling $dir:"
	if [[ -s $dir/_install.sh ]] ; then
		cd $directory
		source _install.sh
		# this should import a _dotfiles_install_$directory function into the space
		basedot=$(basename $directory)
		install_func="_dotfiles_install_$basedot"
		[[ $VERBOSE == true ]] && echo "Installing according to $dir/_install.sh::$install_func."
		install_to=$(get_abs_filename $dir)
		[[ $(type -t $install_func) == 'function' ]] && eval $install_func $install_to $HOME
		unset install_func
		cd ..
	else
		has_dot=false
		if [[ -f $dir/.dot ]] ; then
			has_dot=true
			[[ $VERBOSE == true ]] && echo "Has .dot; will link into $HOME"
			linking_me_softly $dir $HOME/.$dir
		fi
		for dotfile in $dir/.dot-* ; do
			has_dot=true
			[[ ! -f $dotfile ]] && continue
			basedot=$(basename $dotfile)
			newfile=${basedot##.dot-}
			dir=$(dirname $dotfile)
			[[ $VERBOSE == true ]] && echo "Has $basedot; will link $dir into $HOME/$newfile"
			linking_me_softly $dir $HOME/$newfile
		done
		for dotfile in $dir/.??* ; do
		# only link in files
			[[ ! -f $dotfile ]] && continue
			basedot=$(basename $dotfile)
			[[ $basedot == '.dot' || $basedot == .dot-* ]] && continue
			[[ $VERBOSE == true ]] && echo "$basedot is dot-file; will link into $HOME/$basedot"
			linking_me_softly $dotfile $HOME/$basedot
		done
		
	fi
done
