#!/usr/bin/env python

import os
import traceback
import logging

if __name__ == "__main__":
    if os.name == "posix" and os.getenv("XDG_CURRENT_DESKTOP", None) is not None:
        path = "~/.dotfiles"
        outfile = "linux/dconf-guake-dump.txt"
        command = f"dconf dump /apps/guake/ > {outfile}"
        command2 = f"git diff --exit-code {outfile}"
        try:
            os.chdir(os.path.expanduser(path))
            os.popen(command)
            shell = os.popen(command2)
            status = shell.close()
            if status and os.waitstatus_to_exitcode(status) == 1:
                print(f"New settings saved to {outfile}")
                exit(1)
        except Exception:
            logging.error(traceback.format_exc())
            exit(1)
