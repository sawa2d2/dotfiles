# 1Password secrets

Both helpers read secrets with the 1Password CLI (`op`). Their config files
live outside the repository and map a name to a secret reference, one per line:
`name=op://Vault/Item/field`.

| Helper | Config file | Use |
| --- | --- | --- |
| `load-secret` | `~/.config/secret/secrets.conf` | `load-secret NAME` exports it (no argument lists names) |
| `op-ssh-askpass` | `~/.config/secret/ssh-passwords.conf` | Automatic on ssh password prompts |

`load-secret` is a shell function in `home/.shell.d/secret.sh`, since it must
export into the current shell. Values are cached for 30 minutes.

## op-ssh-askpass

For password-only hosts. `home/.shell.d/ssh.sh` enables it when
`ssh-passwords.conf` exists (open a new shell after creating it).

```
myvm=op://Private/myvm/password
admin@myvm=op://Private/myvm-admin/password
```

- Write the host the password prompt shows: the `HostName`, or the
  `HostKeyAlias` when set (handy when the address changes). `user@host` wins.
- Only ssh's own password prompts are answered from 1Password. Anything else,
  an unlisted host, or a failed lookup is asked on the terminal as usual.
- Disable for one command: `SSH_ASKPASS_REQUIRE=never ssh myvm`.

Example `~/.ssh/config` entry for such a host (the Control* lines reuse one
login for 10 minutes; keep them off `Host *`):

```
Host myvm
  HostName 192.168.122.57
  HostKeyAlias myvm
  ControlMaster auto
  ControlPath ~/.ssh/cm-%C
  ControlPersist 10m
```
