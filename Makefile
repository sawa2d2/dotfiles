.PHONY: fmt fmt-check lint check test test-vim test-lua test-json

BASH_CONFIG := .bashrc .bash_aliases $(wildcard .bash.d/*.bash)
FMT_CONFIG := $(filter-out .bash.d/path.bash,$(BASH_CONFIG))
ZSH_CONFIG := .zshrc $(wildcard .zsh.d/*.zsh)
BASH_SCRIPTS := install install-dotfiles-bin.sh theme/sync nix/apply

fmt:
	shfmt -w bin $(FMT_CONFIG)

fmt-check:
	shfmt -d bin $(FMT_CONFIG)

lint:
	shellcheck -s bash $(FMT_CONFIG)

check: fmt-check lint
	@for file in $(BASH_CONFIG) $(BASH_SCRIPTS); do bash -n "$$file" || exit 1; done
	@for file in $(ZSH_CONFIG); do zsh -n "$$file" || exit 1; done

test: check test-vim test-lua test-json

test-vim:
	@if command -v vim >/dev/null 2>&1; then \
		vim -Nu NONE -i NONE -n -es \
			-c 'source .vimrc' -c 'call DotfilesTabline()' -c 'qa!' || exit 1; \
	else echo 'SKIP Vim smoke test (vim unavailable)'; fi
	@if command -v nvim >/dev/null 2>&1; then \
		nvim --headless -u NONE -i NONE \
			-c 'set runtimepath+=./config.d/nvim' \
			-c 'source .vimrc' -c 'call DotfilesTabline()' -c 'qa!' || exit 1; \
	else echo 'SKIP Neovim smoke test (nvim unavailable)'; fi

test-lua:
	@if command -v nvim >/dev/null 2>&1; then \
		find config.d/nvim -type f -name '*.lua' | while IFS= read -r file; do \
			nvim --headless -u NONE -i NONE \
				-c "lua assert(loadfile([[$$file]]))" -c 'qa!' || exit 1; \
		done; \
	else echo 'SKIP Lua syntax test (nvim unavailable)'; fi

test-json:
	@python3 -m json.tool config.d/vscode/settings.json >/dev/null
	@python3 -m json.tool .vscode/extensions.json >/dev/null
