# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'

alias de='cd ~/Desktop'
alias dl='cd ~/Downloads'

# Directory operations
alias md='mkdir -p'
alias rm='trash-put'

# Directory listing
alias ls='ls --color=auto -FA'
alias l='\ls -lhA'
alias ll='\ls -lh'
alias la='\ls -lha'

# Editors
alias vi='nvim'
alias vimrc='$EDITOR ~/.vimrc'
alias er='$EDITOR ~/.bashrc && source ~/.bashrc'
alias sr='source ~/.bashrc'

# Terminal and SSH
alias less='/usr/bin/less -+F'
alias sshconf='vi ~/.ssh/config'

# Development tools
alias qiita='npx qiita'
alias grep='grep --color=auto'

