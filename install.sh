#!/usr/bin/env bash
# -*- coding: utf-8 -*-

## ------------------------------------------------------------------------ ##
##  install.sh                               Nicholas Berlette, 2022-06-02  ##
## ------------------------------------------------------------------------ ##
##        https://github.com/nberlette/dotfiles/blob/main/install.sh        ##
## ------------------------------------------------------------------------ ##
##              MIT © Nicholas Berlette <nick@berlette.com>                 ##
## ------------------------------------------------------------------------ ##

# ask for password right away
sudo -v

# check for curdir
if ! hash curdir &> /dev/null; then
	# determine actual script location
	# shellcheck disable=SC2120
	function curdir()
	{
		dirname -- "$(realpath -Lmq "${1:-"${BASH_SOURCE[0]}"}" 2> /dev/null)"
	}
fi

# check for is_interactive
if ! hash is_interactive &> /dev/null; then
	function is_interactive()
	{
		# if we're in CI/CD, return code 1 immediately
		[ -n "$CI" ] && return 1
		# no? okay, lets check for tty based on stdin, stdout, stderr
		[ -t 0 ] && [ -t 1 ] && [ -t 2 ] && return 0
		# no? then we will check shellargs for -i as a last resort
		case $- in *i*) return 0 ;; esac
		# ..... no?! you're still here? throw an error >_>
		return 2
	}
fi

# source the dotfiles core shell files
DOTFILES_CORE="$(curdir 2> /dev/null || echo -n "$DOTFILES_PREFIX")/.bashrc.d/core.sh"
# shellcheck source=/dev/null
[ -r "$DOTFILES_CORE" ] && . "$DOTFILES_CORE"

# verbosity flag
# default level is --quiet , in CI/CD --verbose
verbosity="--quiet"

# always ebable verbose logging if in CI/CD
[ -n "${CI:+x}" ] && verbosity="--verbose"

# current step number, total step count
declare -i STEP_NUM=1
declare -i STEP_TOTAL=1

# export PNPM homedir to unify the virtual dependency store
export PNPM_HOME="${PNPM_HOME:-"$(dirname -- "$(which pnpm)")"}"
# do not automatically cleanup after installing homebrew packages
export HOMEBREW_NO_INSTALL_CLEANUP=1
# do not show env hints during homebrew install process
export HOMEBREW_NO_ENV_HINTS=1
# tell terminal.app to shut the fuck up about switching the shell to zsh
export BASH_SILENCE_DEPRECATION_WARNING=1

# ensure $TERM is set in CI/CD (gh-actions)
[ -z "${TERM:+x}" ] && export TERM="${TERM:-"xterm-color"}"

# $OSTYPE variable (linux-gnu, darwin, etc)
[ -z "${OSTYPE:+x}" ] && OSTYPE=$(ostype)

# $IS_DARWIN=1 if on a Mac
[[ $OSTYPE == [Dd]arwin* ]] && IS_DARWIN=1 || IS_DARWIN=""

export TZ='America/Los_Angeles'

# IS_INTERACTIVE=1 if interactive, undefined otherwise (duh)
# (like in CI/CD, or Codespaces/Gitpod autoinstall during prebuilds)
export IS_INTERACTIVE="${IS_INTERACTIVE:-"$(is_interactive 2>&1 && echo -n 1)"}"

if [ -e ~/.DOTFILES_BREW_BUNDLE ]; then
  export IS_INTERACTIVE="";
  export DOTFILES_BREW_BUNDLE=1;
fi

export DOTFILES_PREFIX="${DOTFILES_PREFIX:-"$HOME/.dotfiles"}"
# janky solution for platforms (codespaces) cloning into ~/dotfiles rather than ~/.dotfiles
if [ ! -e "$DOTFILES_PREFIX" ] && [ -e "$HOME/dotfiles" ]; then
  export DOTFILES_PREFIX="$HOME/dotfiles"
fi

# declare some global readonly variables we will be using throughout
declare -g -r -x DOTFILES_LOGPATH="$DOTFILES_PREFIX/_installs/$(date +%F)-$(date +%s)"
declare -g -r -x DOTFILES_LOG="${DOTFILES_LOGPATH-}/install.log"
declare -g -r -x DOTFILES_BACKUP_PATH="${DOTFILES_LOGPATH}/.backup"

# ensure our log folder and backup folder exist
[ -d "$DOTFILES_LOGPATH" ] || mkdir -p "$DOTFILES_LOGPATH" &> /dev/null
[ -d "$DOTFILES_BACKUP_PATH" ] || mkdir -p "$DOTFILES_BACKUP_PATH" &> /dev/null

# create the install log file
command touch "$DOTFILES_LOG" &> /dev/null

# helper functions for installation
function print_banner()
{
	local message divider i
	case "${1-}" in
		step)
			printf '\n\033[1;2m(step #%d) \033[0;1m%s\033[0m\n' "$STEP_NUM" "${*:2}"
			((STEP_TOTAL++))
			;;
		*)
			divider="" divider_char="-"
			if (($# > 1)) && [ -n "$2" ]; then
				divider_char="${1:-"-"}"
				message="${*:2}"
			else
				message="${*:-"Beginning dotfiles installation"}"
			fi
			for ((i = 0; i < 80; i++)); do
				divider+="${divider_char:-"="}"
			done
			printf '\n\033[1m %s \033[0m\n\033[2m%s\033[0m\n' "${message-}" "${divider-}"
			;;
	esac
}

# shellcheck disable=SC2120
function print_step_complete()
{
	if (($# > 0)); then
		printf '\n\033[1;48;2;40;60;66;38;2;240;240;240m %s \033[0;2;3m %s\n\n' "${1-}" "${*:2}"
	else
		# display the completed step number and total number of steps
		echo -e '\n\033[1;32m ✓ \033[0;32;3mCompleted step '"$STEP_NUM"'.\033[0m\n'
		# increment step number by 1
		((STEP_NUM++))
	fi
}

# does what it says
function homebrew_determine_prefix()
{
  # are we running macOS?
  if [[ "$(uname -s)" == *[Dd]arwin* ]]; then
    # check for arm64 (apple silicon) install location (/opt/homebrew)
    if [ -d "/opt/homebrew/bin" ]; then
      export HOMEBREW_PREFIX="/opt/homebrew/bin"
    # no? fallback to /usr/local/bin
    else
      export HOMEBREW_PREFIX="/usr/local/bin"
    fi
  # no... then how about Linux?
  elif [[ "$(uname -s)" == [Ll]inux ]]; then
    # check for linuxbrew folder existence
    if [ -e "/home/linuxbrew/.linuxbrew/bin" ]; then
      # set the homebrew prefix variable
      export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew/bin"
    # fallback to /usr/local/bin
    else
      export HOMEBREW_PREFIX="/usr/local/bin"
    fi
  fi
}

# configure homebrew prefix and PATH
function homebrew_postinstall()
{
  # proceed only if HOMEBREW_PREFIX is set and the executable file exists
  if [ -n "${HOMEBREW_PREFIX-}" ] && [ -x "${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/brew}" ]; then
    # ensure the homebrew location is in our $PATH
    if ! echo -n "$PATH" | grep -q "$HOMEBREW_PREFIX"; then
      export PATH="$HOMEBREW_PREFIX:$PATH"
    fi
    printf '\n\033[1;92m ✓ OKAY \033[0;1;2;92m %s \033[0m\n\n' "Homebrew installed at ${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/brew}"
    echo -e '\neval "$(${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/brew} shellenv)"' >> ~/.bashrc
    eval "$(${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/brew} shellenv)"
  else
    printf '\n\033[1;91m ⚠︎ ERROR \033[0;1;2;91m %s \033[0m\n\n' "Homebrew installation failed!"
    exit 1
  fi
}

# install homebrew (if needed)
function homebrew_install()
{
  local INSTALLER_LOCATION="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
  {
    if command -v curl &>/dev/null; then
      curl -fsSL "$INSTALLER_LOCATION" | bash - 2>&1
    elif command -v wget &>/dev/null; then
      wget -qO- "$INSTALLER_LOCATION" | bash - 2>&1
    else
      echo "curl or wget required to install homebrew"
      return 1
    fi
    homebrew_determine_prefix 2>&1 && homebrew_postinstall 2>&1
  } | tee -a "$DOTFILES_LOG" 2>&1
}

# install some commonly-used global packages. the bare minimum.
function setup_brew()
{
	local HOMEBREW_BUNDLE_FILE
  # install homebrew if not already installed
  command -v brew &>/dev/null || homebrew_install

	# set our brewfile location
	export HOMEBREW_BUNDLE_FILE="$(curdir)/.Brewfile"

	# don't install when we're in a noninteractive environment (read: gitpod dotfiles setup task)
	# otherwise this usually takes > 120s and fails hard thanks to gitpod's rather unreasonable time limit.
	# also, skip this step if we're in CI/CD (github actions), because... money reasons.
	if [ -z "${CI:+x}" ] && [ -n "${IS_INTERACTIVE:+x}" ]; then
		# for developing jekyll sites (and other things for github pages, etc)
		# for macOS
		if [ "$IS_DARWIN" = 1 ]; then
			export HOMEBREW_BUNDLE_FILE="$(curdir)/.osx/.Brewfile"
			{
				command -v rvm &> /dev/null || curl -fsSL https://get.rvm.io | bash -s stable --rails
			} 2>&1
			export SHELL="$(which bash)"
		fi
	fi

	if [ -f "$HOMEBREW_BUNDLE_FILE" ] && [ -r "$HOMEBREW_BUNDLE_FILE" ]; then
		# make sure its executable...
		[ -x "$HOMEBREW_BUNDLE_FILE" ] || chmod +x "$HOMEBREW_BUNDLE_FILE" 2> /dev/null
		# and then execute it
		brew bundle install "${verbosity-}" 2>&1
  else
    unset -v HOMEBREW_BUNDLE_FILE
	fi
}

# installs PNPM and Node.js (if needed) and some minimal global packages
function setup_node()
{
	# shellcheck disable=SC2120
	local node_v
	node_v="${1:-lts}"

	local -a global_util_packages=(zx fsxx @brlt/n @brlt/prettier prettier @brlt/eslint-config eslint @brlt/utils degit)
	local -a global_cli_packages=(dotenv-vault vercel wrangler@latest miniflare@latest @railway/cli netlify-cli)

	{
		# install pnpm if not already installed
		if ! command -v pnpm &> /dev/null; then
			curl -fsSL https://get.pnpm.io/install.sh | bash -
		fi
		# ensure we have node.js installed
		if ! command -v node &> /dev/null || ! node -v &> /dev/null; then
			{
				pnpm env use -g "${node_v:-lts}" 2> /dev/null || pnpm env use -g 16
			} && pnpm setup 2> /dev/null
		fi
	} 2>&1

	global_add "${global_util_packages[@]}"

	if [ -z "${IS_INTERACTIVE:+x}" ]; then
		global_add "${global_cli_packages[@]}"
	else # interactive
		read -r -n 1 -i y -t 30 -p $'\n\033[0;1;5;33m⚠  \033[0m\033[1;33mInstall CLIs for Vercel/Railway/Netlify/Cloudflare?\033[0m\n\n\033[0;2m(\033[0;1;4;32mY\033[0;1;2;32mes\033[0;2m / \033[0;1;4;31mN\033[0;1;2;31mo\033[0;2m)\033[0m ... '
		local prompt_status=$?
		echo ''

		if [[ $REPLY == [Yy]* ]] || ((prompt_status > 128)); then
			global_add "${global_cli_packages[@]-}"
		fi
		# STEP_NUM=$((STEP_NUM+1))
	fi

	return 0
}

# setup our new homedir with symlinks to all the dotfiles
function setup_home()
{
	local rsyncfiles rsyncexclude rsyncinclude git_file
	local -a rsyncargs=("-avh" "--recursive" "--perms" "--times" "--checksum" "--itemize-changes" "--human-readable" "--progress" "--log-file=$DOTFILES_LOG" "--backup" "--backup-dir=$DOTFILES_BACKUP_PATH")

	# first off, install rsync if it doesn't exist on the current system
	if ! command -v rsync &> /dev/null; then
    command -v brew &>/dev/null || homebrew_install 2>&1;
		brew install --force --overwrite --quiet rsync coreutils gcc >> "$DOTFILES_LOG" 2>&1
	fi

	# backup (preserving homedir structure), e.g. /home/gitpod/.dotfiles/.backup/home/gitpod/.bashrc~
	[ -d "${DOTFILES_BACKUP_PATH-}" ] || mkdir -p -v "${DOTFILES_BACKUP_PATH-}" | tee -i -a "$DOTFILES_LOG" 2>&1

	# set the default locations for .rsyncfiles and .rsyncexclude files
	rsyncfiles="${DOTFILES_PREFIX-}/.rsyncfiles"
	rsyncexclude="${DOTFILES_PREFIX-}/.rsyncexclude"
	rsyncinclude="${DOTFILES_PREFIX-}/.rsyncinclude"

	# .gitignore and .gitconfig are special!
	# we have to rename them to avoid issues with git applying them to the repository
	for git_file in "gitignore" "gitconfig"; do
		{
			[ -e ~/."$git_file" ] && mv -f -v ~/."$git_file" "${DOTFILES_BACKUP_PATH-}"
		} | tee -i -a "$DOTFILES_LOG" 2>&1
		rsync "${rsyncargs[@]}" "$git_file" ~/."$git_file"
	done

	# exclude files matching glob patterns in the file .dotfiles/.rsyncexclude
	[ -n "${rsyncexclude-}" ] && [ -r "${rsyncexclude-}" ] \
		&& rsyncargs+=(--exclude-from="${rsyncexclude-}")

	# include files with glob patterns in the file .dotfiles/.rsyncinclude
	[ -n "${rsyncinclude-}" ] && [ -r "${rsyncinclude-}" ] \
		&& rsyncargs+=(--include-from="${rsyncinclude-}")

	# explicitly list files to copy in .dotfiles/.rsyncfiles
	[ -n "${rsyncfiles-}" ] && [ -r "${rsyncfiles-}" ] \
		&& rsyncargs+=(--files-from="${rsyncfiles-}")

	# now do the damn thang!
	rsync "${rsyncargs[@]}" "$(curdir 2> /dev/null || echo -n "${DOTFILES_PREFIX:-"$HOME/.dotfiles"}")" "$HOME"

	return 0
}

# runs all the other scripts and cleans up after itself. geronimo!
function main()
{
	# make sure we are in the root ~/.dotfiles directory
	cd "$(curdir)" || return

	clear &> /dev/null # clear the screen of any previous output

	print_banner "Spooling up the dotfiles installer..."
	printf ' \033[1;4m%s\033[0m: %s \n\n' 'Working Dir' "$(curdir)"

  if ! which brew &>/dev/null; then
    {
      print_banner "Installing Homebrew..."
      homebrew_install
    } >> "$DOTFILES_LOG" 2>&1
  fi

  if which brew &>/dev/null; then
    brew install --overwrite rsync coreutils starship gh >> "$DOTFILES_LOG" 2>&1
  fi

	if [ -z "${DOTFILES_SKIP_NODE:+x}" ]; then
    if [ -n "${IS_INTERACTIVE:+x}" ]; then
      print_banner step "$(printf 'Installing \033[1;4;31mPNPM\033[0;1m and \033[4;32mNode\033[0;1;2m v%s\033[0m' "${node_v:-LTS}")"
      # pin node.js to 16.x to prevent breaking errors in >= 17.x
      { setup_node "16.15.0" | tee -i -a "$DOTFILES_LOG" 2>&1; } && print_step_complete
    else
      setup_node "${node_v:-LTS}" | tee -i -a "$DOTFILES_LOG" 2>&1
    fi
	fi

  if [ -z "${DOTFILES_SKIP_HOME:+x}" ]; then
    # if we are in interactive mode (not in CI/CD), ask the user if they want to proceed
    if [ -n "${IS_INTERACTIVE:+x}" ]; then
      # syncing the home directory
      print_banner step $'Syncing \033[1;4;33mdotfiles\033[0;1m to \033[1;3;4;36m'"$HOME"

      read -r -n 1 -i y -t 30 -p $'\n\033[0;1;5;33m ☢︎ \033[0;1;31m DANGER \033[0m\n
\033[0;3;31mContinuing with install will overwrite existing files in \033[3;4m'"$HOME"$'\033[0;3;31m.\033[0m\n
\033[0;1;4;33mAccept and continue?  \033[0;2m ⌚︎ no response in 30s and \033[1m"Yes"\033[0;2m is assumed\n
\033[0;2m(\033[0;1;4;32mY\033[0;1;2;32mes\033[0;2m / \033[0;1;4;31mN\033[0;1;2;31mo\033[0;2m)\033[0m ... '
      # if the user says yes, or force, run the install
      if (($? > 128)) || [[ $REPLY == [Yy]* ]]; then
        echo ''
        { setup_home | tee -i -a "$DOTFILES_LOG" 2>&1; } && print_step_complete
      else
        echo -e '\n\n\033[1;31mAborted.\033[0m' && return 1
      fi # $REPLY
    else
      # otherwise (automated install), proceed to setting up the homedir
      setup_home | tee -i -a "$DOTFILES_LOG" 2>&1
    fi # $-
  fi

  # skip brew bundle on initial install. we'll do it later.
  if [ -n "${DOTFILES_BREW_BUNDLE:+x}" ] || [ -e ~/.DOTFILES_BREW_BUNDLE ]; then
    [ -e ~/.DOTFILES_BREW_BUNDLE ] && rm -f ~/.DOTFILES_BREW_BUNDLE &> /dev/null;

    if [ -n "${IS_INTERACTIVE:+x}" ]; then
      print_banner step $'Installing/upgrading \033[1;4;35mhomebrew\033[0;1m and required formulae...\033[0m\n\n
\033[0;1;5;31m ☢︎ \033[0;1;2;3;33mthis may take a while...\033[0m\n'
      {
        setup_brew | tee -i -a "$DOTFILES_LOG" 2>&1
      } && print_step_complete;
    else
      setup_brew | tee -i -a "$DOTFILES_LOG" 2>&1
    fi
  else
    touch ~/.DOTFILES_BREW_BUNDLE &> /dev/null;
    echo -n $'#!/usr/bin/env bash\n## DO NOT EDIT THIS FILE!\n## created by nberlette/dotfiles/install.sh\n' > ~/.DOTFILES_BREW_BUNDLE
    echo -n $'## '"$(TZ='America/Los_Angeles' date --iso-8601=seconds)"$'\nexport DOTFILES_BREW_BUNDLE=1\n' >> ~/.DOTFILES_BREW_BUNDLE;
    chmod +x ~/.DOTFILES_BREW_BUNDLE &> /dev/null;
  fi

	for cmd_alias in gpg gh starship; do
		# symlink the alias to the actual command for any missing binaries
		if command -v "$cmd_alias" &> /dev/null && [ ! -x "/usr/local/bin/$cmd_alias" ]; then
			sudo ln -sf "$(command -v "$cmd_alias" 2>&1)" "/usr/local/bin/$cmd_alias"
		fi
	done
	# ensure gpg folder has the right perms
	chmod 700 ~/.gnupg &> /dev/null

	return 0
}

function cleanup_env()
{
	unset -v STEP_NUM STEP_TOTAL verbosity IS_INTERACTIVE IS_DARWIN cmd_alias 2> /dev/null
	unset -f main setup_home setup_node setup_brew print_step_complete print_banner global_add is_interactive 2> /dev/null
}

# run dat shizzle
{
	main "$@" || code=$?
}

# shellcheck disable=SC2248
cleanup_env && unset -f cleanup_env &> /dev/null && exit ${code:-0}
