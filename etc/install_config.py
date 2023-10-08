#!/usr/bin/env python3

import os
from pathlib import Path

current_directory = os.path.dirname(os.path.realpath(__file__))
config_d_path = normalized_path = os.path.normpath(f"{current_directory}/../config.d")
home_config_dir = f"{os.environ['HOME']}/.config"

for filepath in Path(config_d_path).rglob('*'):
    if filepath.is_file():
        source_path = filepath.resolve()
        relative_path = os.path.relpath(source_path, config_d_path)
        target_path = f"{home_config_dir}/{relative_path}"
        if os.path.exists(target_path):
            print(f"Skip: Target `{target_path}` exists.")
        else:
            os.symlink(source_path, target_path)
            print(f"Link created: {source_path}->`{target_path}`")
