# Terminal display redaction

The optional `bin/terminal-redacted` entry point launches a login shell (or
a command) through [hushterm](https://github.com/trilliumsmith/hushterm).
hushterm filters PTY output before it reaches the visible terminal.
This feature is **opt-in**; normal shell startup is unchanged.

## Setup

Install hushterm separately (for example through Go or a Nix package, if
available), then create a **local** blocklist:

```sh
mkdir -p ~/.config/hushterm/blocklists
cp config/hushterm/personal.example.yaml ~/.config/hushterm/blocklists/personal.yaml
chmod 700 ~/.config/hushterm ~/.config/hushterm/blocklists
chmod 600 ~/.config/hushterm/blocklists/personal.yaml
${EDITOR:-vi} ~/.config/hushterm/blocklists/personal.yaml
```

Put the most specific values first (such as full home paths before usernames).
Never add real names, addresses, paths, credentials, or tokens to this repo.
Use `case_sensitive: true` to avoid unexpected replacements; change it
explicitly if case-insensitive matches are wanted.

## Run

```sh
bash bin/terminal-redacted
bash bin/terminal-redacted -- bash -lc 'printf "%s\\n" "my-private-hostname"'
```

The optional command is passed verbatim; no shell interpolation is performed
by the wrapper. Avoid trying to test secrets by typing them into shell history.

## Limits

- Only PTY **output** of programs started under the wrapper is filtered.
  This is not a terminal-wide security feature; other tabs/windows and
  applications are unaffected.
- Input, source files, command histories, and AI tools reading files directly
  are **not** redacted.
- A PTY redactor cannot guarantee masking of every secret. Formatting,
  escape sequences, chunk boundaries, output transformation, or unsupported
  terminal features can defeat matching. Review material before sharing.
- tmux, Vim/Neovim and other full-screen TUIs may have display compatibility
  issues; test before using it as the default interactive environment.
- Builtin detection rules may additionally mask IPs and tokens; configure
  hushterm separately if those defaults cause false positives.
