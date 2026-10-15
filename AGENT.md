# Agent instructions

## Think before coding

- Inspect relevant code and existing conventions before editing.
- Surface material assumptions and trade-offs rather than inventing requirements.
- Ask only when ambiguity would materially change the result; otherwise choose a conservative interpretation.
- Explain when a proposed solution is more complex than the requirement warrants.

## Prefer simple solutions

- Implement the minimum complete solution.
- Prefer straightforward control flow over unnecessary helpers, abstractions, or configuration.
- Avoid speculative options, compatibility layers, and checks for impossible states.
- More lines or more functions do not automatically make code more readable.

## Make surgical changes

- Change only what the task requires; preserve unrelated formatting and behavior.
- Follow existing repository conventions.
- Remove temporary artifacts introduced by your changes.
- Never silently overwrite user data or configuration.

## Verify results

- Define observable completion criteria.
- Run relevant checks when possible; for shell scripts, check syntax and applicable dry-run behavior.
- Report what was actually tested and what remains unverified.
- Distinguish GitHub commits from changes installed or executed on the user's machine.

## Dotfiles-specific rules

- Preserve the distinction between per-user and system-wide installation.
- Treat PATH precedence, ownership, sudoers changes, and privileged installation as security-sensitive.
- In Zsh-sourced functions, avoid local names that collide with special parameters (especially `path`/`PATH`, `status`, and `commands`); Bash-only variables are unaffected.
- Keep patches focused and commit messages concise.
- Work on a dedicated branch unless instructed otherwise. Never create PRs, squash, or merge without an explicit request.
