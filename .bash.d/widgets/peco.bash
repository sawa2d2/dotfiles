export HISTCONTROL="ignoredups"

peco_search_history() {
	local l=$(HISTTIMEFORMAT= history | \
	sort -r | sed -E s/^\ *[0-9]\+\ \+// | \
	peco --layout=bottom-up --query "$READLINE_LINE")
	READLINE_LINE="$l"
	READLINE_POINT=${#l}
}
bind -x '"\C-r": peco_search_history'