# Initialize Zsh completion
autoload -Uz compinit
compinit

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Display completion candidates immediately
setopt AUTO_LIST
setopt LIST_AMBIGUOUS

# Append / to completed directories
setopt AUTO_PARAM_SLASH

# Show file types and colors
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Completion menu
zstyle ':completion:*' menu select