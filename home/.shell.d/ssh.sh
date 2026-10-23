# Let ssh take passwords from 1Password for hosts listed in
# ~/.config/secret/ssh-passwords.conf (see bin/secret/README.md). Other
# prompts are still asked on the terminal, so this is safe for every ssh.
if [[ -n ${DOTPATH:-} && -f $HOME/.config/secret/ssh-passwords.conf ]]; then
    export SSH_ASKPASS="$DOTPATH/bin/secret/op-ssh-askpass" SSH_ASKPASS_REQUIRE=force
fi
