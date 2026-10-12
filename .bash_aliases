# Default ls: colors, one item per line, type markers, hidden files (except . and ..).
alias ls='ls --color=auto -1FA'
# Preserve previously requested long-view aliases independently of ls alias.
alias l='\ls -lhA'
alias ll='\ls -lh'
alias la='\ls -lha'

alias er='vim ~/.bashrc && source ~/.bashrc'
alias sr='source ~/.bashrc'
alias vimrc='vim ~/.vimrc'
alias rm='trash-put'
alias qiita='npx qiita'
alias vi='nvim'
alias ide='NVIM_APPNAME=lazyvim nvim'
alias grep='grep --color=auto'
