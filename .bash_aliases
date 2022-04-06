#!/usr/bin/env bash

os="${os:-"$(uname -s | tr '[:upper:]' '[:lower:]')"}"
case "$os" in
	darwin)
		colorflag="-G --color=always"
		export COLORTERM=1
		export CLICOLOR_FORCE=$COLORTERM
		alias rebash="source \$HOME/.bash_profile"
		;;
	linux)
		colorflag="--color=always"
		alias pbcopy='xclip -selection clipboard'
		alias pbpaste='xclip -selection clipboard -o'
		alias rebash="source \$HOME/.bashrc"
		;;
esac
datetimesep=$'\e[2;3m at \e[m'
dateflag="-D \$' \\e[0;2;3mM:\\e[m \\e[2m%D\\e[m${datetimesep:- }\\e[2m%H\\e[5m:\\e[0;2m%M\\e[m '"
alias realias=". \$HOME/.bash_aliases"
export EDITOR="${EDITOR:-nvim}"
alias valias="\${EDITOR:-vi} $HOME/.bash_aliases"
alias rebash=". \$HOME/.bashrc"
alias vi="vim -X"
alias vim="vim -X"
alias gitb="git branch -a"
alias gitbl="git branch"
alias gitba="git branch -a"
alias gitd="git diff"
alias gitds="git diff --staged"
alias gitf="git format-patch main.."
alias gitfs="git format-patch --stdout main.."
alias gitdm="git diff main.."
alias gits="git status -uno"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ~="cd ~"
alias -- -="cd -"
alias dl="cd ~/Downloads"
alias g="git"
alias h="history"
alias gc='. $(which gitdate) && git commit -v '
if type -t nvim > /dev/null 2>&1; then
	alias vim="nvim"
	alias vi="nvim"
	alias v="nvim"
else
	alias vim="vim"
	alias vi="vim"
	alias v="vim"
fi
if hash which >&/dev/null; then
	:
else
	alias which='type -a'
fi
if ! hash docker >&/dev/null; then
	alias dk='docker'
	alias dkit='docker -it'
	alias dkr='docker run -it'
	alias dkc='docker compose'
	alias dkb='docker build -it'
	alias dkp='docker push'
	alias dkpull='docker pull'
fi
alias ls="command ls $colorflag"
alias ll="command ls -FAHlosh -% ${colorflag-} $dateflag"
alias la="command ls -loFAhHk -sa ${colorflag-}"
alias lsd="command ls -lhF $colorflag | grep --color=always '^d'"
alias grep='grep --color=auto '
alias sudo='sudo '
alias week='date +%V'
alias timer='echo "Timer started. Stop with Ctrl-D." && date && time cat && date'
alias pubip="dig +short myip.opendns.com @resolver1.opendns.com"
alias localip="sudo ifconfig | grep -Eo 'inet (addr:)?([0-9]*\\.){3}[0-9]*' | grep -Eo '([0-9]*\\.){3}[0-9]*' | grep -v '127.0.0.1'"
alias ips="sudo ifconfig -a | grep -o 'inet6\\? \\(addr:\\)\\?\\s\\?\\(\\(\\([0-9]\\+\\.\\)\\{3\\}[0-9]\\+\\)\\|[a-fA-F0-9:]\\+\\)' | awk '{ sub(/inet6? (addr:)? ?/, \"\"); print }'"
alias flush="dscacheutil -flushcache && killall -HUP mDNSResponder"
alias sniff="sudo ngrep -d 'en1' -t '^(GET|POST) ' 'tcp and port 80'"
alias httpdump="sudo tcpdump -i en1 -n -s 0 -w - | grep -a -o -E \"Host\\: .*|GET \\/.*\""
type -p hexdump >&/dev/null && command -v hd > /dev/null || alias hd="hexdump -C"
type -p md5 >&/dev/null && command -v md5sum > /dev/null || alias md5sum="md5"
type -p shasum >&/dev/null && command -v sha1sum > /dev/null || alias sha1sum="shasum"
alias trc="tr -d '\\n' | pbcopy"
if type -p python >&/dev/null; then
	alias urlencode='python -c "import sys, urllib as ul; print ul.quote_plus(sys.argv[1]);"'
fi
alias map="xargs -n1"
if type -t lwp-request >&/dev/null; then
	for method in GET HEAD POST PUT DELETE TRACE OPTIONS; do
		alias "$method"="lwp-request -m \"$method\""
	done
fi
alias chromekill="ps ux | grep '[C]hrome Helper --type=renderer' | grep -v extension-process | tr -s ' ' | cut -d ' ' -f2 | xargs kill"
if type -t i3lock >&/dev/null; then
	alias afk="i3lock -c 000000"
fi
alias hosts='sudo nvim /etc/hosts'
alias cwd='pwd | tr -d "\r\n" | pbcopy'
alias cp='cp -i -v'
alias mv='mv -i -v'
alias untar='tar xvf'
alias success='status success'
alias failure='status failure'
alias warning='status warning'
alias brewup='brew update; brew upgrade; brew prune; brew cleanup; brew doctor'
alias chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
alias c='clear'
alias pip2='/usr/local/bin/pip'
alias pip='pip3'
alias python='python3'
alias venv="source '\$HOME/.venv/bin/activate'"
if which aws >&/dev/null; then
	alias ls3='aws s3 ls --human-readable --summarize'
	alias rls3='aws s3 ls --recursive'
	for aws_cmd in s3 iam amplify apigateway appconfig ddb docdb dynamodb devicefarm ec2 ecr ecs lambda memorydb rds route53 ses sms sns sqs; do
		alias "${aws_cmd-}"="aws ${aws_cmd-}"
		alias "${aws_cmd-}-h"="aws ${aws_cmd-}"
	done
fi
alias cls='clear && ls'
alias cll='clear && ll'
alias cla='clear && la'
alias cl='clear && l'
alias rm='rm -v -i'
alias rmr='rm -r'
alias rmrf='rm -rf'
alias rimraf='rm -rf'
alias cpr='cp -R'
alias mkdir='mkdir -p'
alias cd..='cd ..'
alias t='touch'
alias gitignore='git ignore'
alias ignore='git ignore'
alias gitingore='git ignore'
alias ingore='git ignore'
if type gh >&/dev/null; then
	alias mkgist="gh gist create"
	alias rmgist="gh gist delete"
	alias gisted='gh gist edit'
	alias fork='gh repo fork'
	alias clone='gh repo clone'
	alias repo='gh repo'
	alias reponew='gh repo create'
	alias newrepo='gh repo create'
	alias mkrepo='gh repo create'
fi
alias finder="open -a '/System/Library/CoreServices/Finder.app'"
alias vscode="open -a '/Applications/Visual Studio Code.app'"
if ! type -t code >&/dev/null; then
	alias code="open -a '/Applications/Visual Studio Code.app'"
fi
alias prisma='pnpx prisma'
alias next='pnpx next'
alias sk='pnpx svelte-kit'
alias ska='pnpx svelte-add'
alias degit='pnpx degit'
alias gem='sudo gem'
alias pig='pnpm i -g'
alias nig='npm i -g'
alias yag='yarn global add'
alias yg='yarn global'
alias yga='yg add --ignore-platform --ignore-optional'
alias ygr='yg remove'
alias ya='yarn add --ignore-platform --ignore-optional'
alias yr='yarn remove'
alias yorn='yarn --offline'
alias yporn='yarn --prefer-offline'
if [[ $TERM_PROGRAM == "iTerm.app" ]]; then
	if type -t it2setcolor >&/dev/null; then
		alias godark="it2setcolor preset 'Dark Background'"
		alias darkmode="godark"
		alias golight="it2setcolor preset 'Light Background'"
		alias lightmode="golight"
		alias itheme="it2setcolor preset"
		alias themeit="it2setcolor preset"
		alias it2="it2setcolor preset"
		alias itab="it2setcolor tab"
		alias tabit="it2setcolor tab"
		alias tabcolor="it2setcolor tab"
	fi
	if type -t it2setkeylabel >&/dev/null; then
		alias itouch="it2setkeylabel"
		alias tbar="it2setkeylabel"
		alias touchpush="it2setkeylabel push"
		alias touchpop="it2setkeylabel pop"
		alias touchset="it2setkeylabel set"
		alias statuskey="touchset status"
	fi
fi
NODE_FLAGS=${NODE_FLAGS:-"--experimental-import-meta-resolve --experimental-json-modules --experimental-repl-await --experimental-specifier-resolution=node --experimental-vm-modules --max-old-space-size=4096 "}
alias "esnode"="node --trace-warnings \$NODE_FLAGS -r esm -r dotenv/config"
alias "tsnode"="node  \$NODE_FLAGS -r tsm -r dotenv/config"
alias sgr0='tput sgr0'
alias setaf='tput setaf'
alias setab='tput setab'
function __osc() {
	local str __ifs
	__ifs=$IFS
	IFS=';' str="$*"
	IFS=$__ifs
	printf '\033[%sm' "$str"
}
alias bold="__osc 01"
alias undl="__osc 04"
alias ital="__osc 03"
alias dark="__osc 02"
alias flsh="__osc 05"
alias inv="__osc 07"
alias reset="__osc 00"
alias blk="__osc 38 02 00 00 00"
alias red="__osc 01 31"
alias grn="__osc 01 32"
alias ylw="__osc 01 33"
alias blu="__osc 01 34"
alias mag="__osc 01 35"
alias cyn="__osc 01 36"
alias wht="__osc 38 02 255 255 255"
alias gry="__osc 37"
alias blk_b="__osc 48 02 00 00 00"
alias red_b="__osc 01 41"
alias grn_b="__osc 01 42"
alias ylw_b="__osc 01 43"
alias blu_b="__osc 01 44"
alias mag_b="__osc 01 45"
alias cyn_b="__osc 01 46"
alias wht_b="__osc 48 02 255 255 255"
alias __print_msg="__status"
alias status="__status"
alias gpg_unlock='echo "" | gpg --clear-sign --pinentry-mode loopback >/dev/null'
alias gpg_init='gpg_unlock >/dev/null && __status "ok" "GPG is ready to sign commits and tags" '
if which flarectl >&/dev/null; then
	alias flare="flarectl"
	alias cf=flarectl
	alias railgun="flarectl railgun"
fi
if which wrangler >&/dev/null; then
	alias wr="wrangler"
	alias pages="wrangler pages"
	alias r2="wrangler r2"
	alias kvns="wrangler kv:namespace"
	alias kv="wrangler kv:key"
	alias kvbulk="wrangler kv:bulk"
fi
