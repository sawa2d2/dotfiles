.PHONY: fmt fmt-check lint check

BASH_CONFIG := .bashrc .bash_aliases $(wildcard .bash.d/*.bash)
FMT_CONFIG := $(filter-out .bash.d/path.bash,$(BASH_CONFIG))
ZSH_CONFIG := .zshrc $(wildcard .zsh.d/*.zsh)

fmt:
	shfmt -w bin $(FMT_CONFIG)

fmt-check:
	shfmt -d bin $(FMT_CONFIG)

lint:
	shellcheck -s bash $(FMT_CONFIG)

check: fmt-check lint
	@for file in $(BASH_CONFIG); do bash -n "$$file" || exit; done
	@for file in $(ZSH_CONFIG); do zsh -n "$$file" || exit; done
