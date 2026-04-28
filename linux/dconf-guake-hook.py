#!/usr/bin/env python

import os
import subprocess
import traceback
import logging

def get_guake_path():
    try:
        result = subprocess.run(['gsettings', 'list-schemas'], capture_output=True, text=True)
        schemas = result.stdout.splitlines()
        if 'org.guake' in schemas or 'guake' in schemas:
            return "/org/guake/"
    except Exception:
        pass
    return "/apps/guake/"

if __name__ == "__main__":
    if os.name == "posix" and os.getenv("XDG_CURRENT_DESKTOP", None) is not None:
        path = "~/.dotfiles"
        outfile = "linux/dconf-guake-dump.txt"
        guake_path = get_guake_path()
        command = f"dconf dump {guake_path} > {outfile}"
        command2 = f"git diff --exit-code {outfile}"
        try:
            os.chdir(os.path.expanduser(path))
            os.popen(command)
            shell = os.popen(command2)
            status = shell.close()
            if status and os.waitstatus_to_exitcode(status) == 1:
                print(f"New settings saved to {outfile} (from {guake_path})")
                exit(1)
        except Exception:
            logging.error(traceback.format_exc())
            exit(1)
