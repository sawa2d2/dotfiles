.PHONY: format format-check lint check

# private.d is a separate repository with its own owner; never touch it here.
EXCLUDE := private.d
# Discover shell scripts by shebang/extension; include rc files without either.
SHELL_FILES := $(sort $(filter-out $(EXCLUDE)/% ./$(EXCLUDE)/%,$(shell shfmt -f .)) \
	$(shell find home -type f \
	\( -name '.bashrc' -o -name '.bash_aliases' -o -name '.zshrc' -o -name '*.zsh' \)))
# shfmt and ShellCheck do not support Zsh-specific syntax in shared/Zsh modules.
ZSH_FILES := $(filter %.zsh %.zshrc,$(SHELL_FILES))
SHARED_FILES := $(filter ./home/.shell.d/% home/.shell.d/%,$(SHELL_FILES))
BASH_FILES := $(filter-out $(ZSH_FILES) $(SHARED_FILES),$(SHELL_FILES))
# The mixed Bash/Zsh modules are syntax-checked by both interpreters instead.
# Ruff discovers .py files itself; add extensionless Python entry points by shebang.
PYTHON_SCRIPTS := $(shell find bin -type f -exec awk 'FNR == 1 && /^#!.*python/ { print FILENAME }' {} +)

format:
	shfmt -w $(BASH_FILES)
	ruff check --fix --extend-exclude $(EXCLUDE) . $(PYTHON_SCRIPTS)
	ruff format --extend-exclude $(EXCLUDE) . $(PYTHON_SCRIPTS)

format-check:
	shfmt -d $(BASH_FILES)
	ruff check --extend-exclude $(EXCLUDE) . $(PYTHON_SCRIPTS)
	ruff format --check --extend-exclude $(EXCLUDE) . $(PYTHON_SCRIPTS)

lint:
	shellcheck -s bash $(BASH_FILES)

check: format-check lint
	@for file in $(BASH_FILES) $(SHARED_FILES); do bash -n "$$file" || exit; done
	@if [ -n "$(ZSH_FILES) $(SHARED_FILES)" ]; then \
		if command -v zsh >/dev/null 2>&1; then \
			for file in $(ZSH_FILES) $(SHARED_FILES); do zsh -n "$$file" || exit; done; \
		else \
			echo "SKIP: zsh syntax check (zsh not installed)"; \
		fi; \
	fi
