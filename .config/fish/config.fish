function fish_user_key_bindings
  bind \cr 'peco_select_history (commandline -b)'
  bind \c] peco_change_directory
  bind \cg\co ghq_peco_repo
  bind \cg\cs peco_gists
  #bind \cg\cg peco_gists
end

# Load Token
set FISH_TOKEN $HOME/.config/fish/token.fish
if test -f $FISH_TOKEN
  source $FISH_TOKEN
end

abbr dor 'docker run -it --rm -v $PWD/app:app NAME /bin/bash'
abbr dob 'docker build -t NAME .'

alias bash='bash --norc'
alias g='git'
alias de='cd ~/Desktop' 

function ide
  tmux split-window -v -p 30
  tmux split-window -h -p 40
  tmux select-pane -L
  tmux select-pane -U
end

