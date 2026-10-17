# iTerm2

On macOS, `./install` shallow-clones [iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes) into `~/.local/share/iTerm2-Color-Schemes`, skipping it if the destination already exists. `--dry-run` does not clone anything.

Import Molokai:

```bash
open "$HOME/.local/share/iTerm2-Color-Schemes/schemes/Molokai.itermcolors"
```

Then select **Settings → Profiles → Colors → Color Presets → Molokai**. Installation does not modify iTerm2 preferences.
