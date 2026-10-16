# Shared palette (single source of truth).
# Theme is selected by the required argument to theme/sync.
# Available: teal, violet, orange, blue

COLOR_FG='#222222'
COLOR_ACTIVE='#393939'
COLOR_HOVER_BG='#555555'
COLOR_INACTIVE='#aaaaaa'
COLOR_WHITE='#f4f4f4'
COLOR_PREFIX='#004144'
COLOR_BORDER_ACTIVE='#ffffff'

# Accent: prominent UI detail; Selected: softer, readable selection background.
case "$THEME_VARIANT" in
    teal)
        COLOR_ACCENT='#1bafb5'
        COLOR_SELECTED='#79bfc0'
        ;;
    violet)
        COLOR_ACCENT='#9180d8'
        COLOR_SELECTED='#b1a5e5'
        ;;
    orange)
        COLOR_ACCENT='#d98d50'
        COLOR_SELECTED='#e9b888'
        ;;
    blue)
        COLOR_ACCENT='#1192e8'
        COLOR_SELECTED='#75b8ed'
        ;;
    red)
        COLOR_ACCENT='#da4e58'
        COLOR_SELECTED='#ed9298'
        ;;
    green)
        COLOR_ACCENT='#24a86a'
        COLOR_SELECTED='#82cfaa'
        ;;
    *)
        printf 'Unknown theme variant: %s\n' "$THEME_VARIANT" >&2
        return 1 2>/dev/null || exit 1
        ;;
esac

# Match the tmux status bar background to the active theme.
COLOR_BG="$COLOR_ACCENT"

# Diagnostics: distinct from focus; muted versions remain legible on inactive bars.
COLOR_DIAG_ERROR='#e27983'
COLOR_DIAG_WARN='#e5a45b'
COLOR_DIAG_ERROR_INACTIVE='#902c3b'
COLOR_DIAG_WARN_INACTIVE='#805000'

COLOR_GIT_CLEAN='#55c9a6'
COLOR_GIT_DIRTY='#e5a45b'
COLOR_GIT_STAGED='#70aee0'
COLOR_GIT_MIXED='#e27983'
