#!/usr/bin/env bash

if [ -z "$CI" ]
then 
    talkative="--quiet"
else 
    talkative="--verbose"
fi

function curdir () {
	printf "%s" "$(readlink -f "$(dirname -- "${BASH_SOURCE[0]}")")" || echo -n "$PWD";
}

# setup our new homedir with symlinks to all the dotfiles
function setup_home() {
	local DIR file d b
	os="$(uname | tr '[:upper:]' '[:lower:]')"
	DIR="$(readlink -f "$(dirname -- "${BASH_SOURCE[0]}")")"
	for file in $(find "${DIR:-.}" -type f -name ".*" -not -name ".git*" -not -name ".*swp" -depth 1); do
		# local d="$(dirname -- "$file" | sed -e 's|\('"$DIR"'\)|'"$HOME"'|')"
		local b="$(basename -- "$file")"
		ln -sfn "$file" "$HOME/$b"
	done
	for file in $(find "${DIR:-.}/.gitconfig.d" -type f -name "*" -not -name "*.swp" -not -name "*.*" -depth 1); do
		d="$(dirname -- "$file" | sed -e 's|\('"$DIR"'\)|'"$HOME"'|')"
		b="$(basename -- "$file")"
		mkdir -p "$d" > /dev/null 2>&1
		ln -sfn "$file" "$d/$b"
	done
	for file in $(find "${DIR:-.}/.gnupg" -type f -name "*.conf" -depth 1); do
		d="$(dirname -- "$file" | sed -e 's|\('"$DIR"'\)|'"$HOME"'|')"
		b="$(basename -- "$file")"
		mkdir -p "$d" > /dev/null 2>&1
		ln -sfn "$file" "$d/$b"
	done
	ln -sfn "$DIR/.gitconfig" "$HOME/.gitconfig"
	ln -sfn "$DIR/.gitignore" "$HOME/.gitignore"
}

# install homebrew (if needed) and some commonly-used global packages. the bare minimum.
function setup_brew() {
	local os is_macos talkative
	[ -z "$CI" ] && talkative="--quiet" || talkative="--verbose"
	os="$(uname | tr '[:upper:]' '[:lower:]')"
	[ "$os" = "darwin" ] && is_macos=1

	# install homebrew if not already installed
	if ! which brew >&/dev/null; then
		curl -fsSL https://raw.github.com/Homebrew/install/HEAD/install.sh | bash -
	fi

	# execute now just to be sure its available for us immediately
	eval "$(brew shellenv 2> /dev/null)"

	# don't install when we're in a gitpod environment
	# otherwise this step takes > 120 seconds and fails to install.
	# also skip this step if we're in CI/CD (github actions), because reasons.
	if [ -z "$GITPOD_TASKS" ] && [ -z "$CI" ]; then
	    
	    # install some essentials
	    brew install "${talkative-}" --overwrite \
		gcc \
		cmake \
		make \
		bash \
		gh \
		git \
		git-extras \
		go \
		python \
		pygments \
		shfmt \
		jq \
		neovim \
		starship \
		lolcat \
		fontforge \
		supabase/tap/supabase \
		docker \
		shellcheck \
		fzf \
		2> /dev/null

		
	    ###  macOS stuff
	    ### --------------------------------- ###
	    if [[ "$(uname -s)" == "Darwin" ]]; then
		brew tap jeroenknoops/tap
		brew install "${talkative-}" \
			gcc coreutils gitin gpg gpg-suite pinentry-mac python3

			export SHELL="${HOMEBREW_PREFIX:-}/bin/bash"
			brew install --quiet --cask iterm2
			curl -fsSL https://iterm2.com/shell_integration/install_shell_integration_and_utilities.sh | bash -

			# Google Chrome, Prisma, PIA VPN
			brew tap homebrew/cask-versions
			brew tap homebrew/cask-fonts
			brew install --casks font-fira-code font-oswald font-ubuntu font-caskaydia-cove-nerd-font fontforge \
				graphql-playground prisma-studio private-internet-access qlmarkdown \
				visual-studio-code visual-studio-code-insiders \
				google-chrome google-chrome-canary firefox firefox-nightly

	    else
		brew install --overwrite gnupg gnupg2
	    fi
	fi
}

function global_add() {
	local pkg pkgs
	pkgs=("$@")
	pnpm add -g "$@" >&/dev/null && {
		echo "Successfully installed $# global packages!"
		for pkg in "${pkgs[@]}"; do
			echo "  - $pkg"
		done
	}
}

# installs PNPM and Node.js (if needed) and some minimal global packages
function setup_node() {
	# shellcheck disable=SC2120
	local node_v
	node_v="${1:-lts}"

	# install pnpm if not already installed
	if ! which pnpm >&/dev/null; then
		curl -fsSL https://get.pnpm.io/install.sh | bash - 2> /dev/null
	fi

	# install node.js  if we don't have it yet
	if ! which node >&/dev/null || ! node -v >&/dev/null; then
		pnpm env use -g "${node_v:-lts}" 2> /dev/null || pnpm env use -g lts
	fi

	global_add \
		pnpm npm yarn @antfu/ni degit @types/node typescript tslib tsm \
		tsup ts-node eslint standard prettier prettier-plugin-sh \
		shellcheck vercel turbo wrangler@0.0.24 miniflare@2.4.0 \
		@dotenv/cli worktop@next svelte @sveltejs/kit@next \
		tailwindcss postcss autoprefixer windicss sirv-cli microbundle \
		2> /dev/null

	unset -f global_add
}

# runs all the other scripts and cleans up after itself. geronimo!
function main() {
	clear
	echo -e "\\n\\033[1mBeginning dotfiles install. This may take a while...\\033[0m"
	echo -e "-------------------------------------------------------\\n"
	echo "WORKDIR: $(readlink -f "$(dirname -- "${BASH_SOURCE[0]}")")"

	if [[ "$(uname -s)" == "Darwin" ]]; then
		export PATH="$HOME/Library/pnpm:/usr/local/bin:/usr/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
	else
		export PATH="$HOME/.local/share/pnpm:/usr/local/bin:/usr/local/sbin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
	fi

	echo "Installing homebrew (if needed) and packages..."
	setup_brew && unset -f setup_brew
	sleep 1 && clear

	echo "Finished homebrew setup. Installing Node.js and PNPM..."
	setup_node && unset -f setup_node
	sleep 1 && clear

	echo "Finished Node/PNPM setup. Linking dotfiles to HOMEDIR..."
	setup_home && unset -f setup_home
	sleep 1 && clear

	echo "Done! Restarting Bash env, buckle your seatbelt..."
	sleep 3 && clear

	# shellcheck source=/dev/null
	source $HOME/.bashrc 2> /dev/null || return 4
	return 0
}

# run it and clean up after!
main && unset -f main && exit 0
