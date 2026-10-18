.PHONY: format format-check lint check

BASH_CONFIG := home/.bashrc home/.bash_aliases $(wildcard home/.bash.d/*.bash)
FMT_CONFIG := $(filter-out home/.bash.d/path.bash,$(BASH_CONFIG))
ZSH_CONFIG := home/.zshrc $(wildcard home/.zsh.d/*.zsh)
PYTHON_SCRIPTS := bin/k8s/generate_inventory bin/tmux-bin/tmux-session

format:
	shfmt -w bin $(FMT_CONFIG)
	ruff check --fix $(PYTHON_SCRIPTS)
	ruff format $(PYTHON_SCRIPTS)

format-check:
	shfmt -d bin $(FMT_CONFIG)
	ruff check $(PYTHON_SCRIPTS)
	ruff format --check $(PYTHON_SCRIPTS)

lint:
	shellcheck -s bash $(FMT_CONFIG)

check: format-check lint
	@for file in $(BASH_CONFIG); do bash -n "$$file" || exit; done
	@for file in $(ZSH_CONFIG); do zsh -n "$$file" || exit; done
