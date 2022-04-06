#!/usr/bin/env bash
shell="$(which bash)"
export SHELL="$shell"
export DOTFILES_PREFIX="${DOTFILES_PREFIX:-"$HOME/.dotfiles"}"
[ -r "${DOTFILES_PREFIX:-.}/.path" ] && source "${DOTFILES_PREFIX:-.}/.path"
# import all vars from .env + .extra into current environment
srx "${DOTFILES_PREFIX:-.}"/.{env,extra}
# include our core bash environment
src "${DOTFILES_PREFIX:-.}"/.{exports,functions,bash_aliases}
# ruby version manager
src "${DOTFILES_PREFIX:-.}/.rvm/scripts/rvm"
# TODO: move this to an install script so it's always ready on runtime
function __prompt() {
	if which starship >&/dev/null; then
		eval "$(starship completions bash 2> /dev/null)"
		eval "$(starship init bash 2> /dev/null)"
	else
		brew install starship --quiet && __prompt
	fi
}
__prompt && unset -v __prompt
