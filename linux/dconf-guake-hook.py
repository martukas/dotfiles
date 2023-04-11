#!/usr/bin/env python

import os
import traceback
import logging

if __name__ == "__main__":
    if os.name == "posix":
        path = "~/.dotfiles"
        command = "dconf dump /apps/guake/ > linux/dconf-guake-dump.txt"
        try:
            os.chdir(os.path.expanduser(path))
            os.popen(command)
            # \TODO: exit 1 if file changed
        except Exception:
            logging.error(traceback.format_exc())
