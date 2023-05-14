#!/usr/bin/env python

import os
import traceback
import logging
import shutil


def git_file_changed(root_path, file_path):
    try:
        os.chdir(os.path.expanduser(root_path))
        shell = os.popen(f"git diff --exit-code {file_path}")
        status = shell.close()
        print(f"status = {status} or {os.waitstatus_to_exitcode(status)}")
        if status and os.waitstatus_to_exitcode(status) != 0:
            print(f"File changed {root_path}/{file_path}")
            return True
    except Exception:
        logging.error(traceback.format_exc())
        exit(1)
    return False


def copy_file_and_diff(machine_path, repo_path, file_path):
    print(f"Copying {machine_path / file_path} to {repo_path / file_path}")
    shutil.copy(machine_path / file_path, repo_path)
    ret = git_file_changed(repo_path, file_path)
    print(f"ret = {ret}")
    return ret


if __name__ == "__main__":
    if os.name == "posix":
        from pathlib import Path
        p = Path('~').expanduser()
        machine = p / ".config/xfce4"
        repo = p / ".dotfiles/linux/config/xfce4"
        try:
            changed = False
            changed = copy_file_and_diff(machine / "panel", repo / "panel", "whiskermenu-1.rc") or changed
            machine2 = machine / "xconf/xfce-perchannel-xml"
            repo2 = repo / "xconf/xfce-perchannel-xml"
            changed = copy_file_and_diff(machine2, repo2, "keyboard-layout.xml") or changed
            if changed:
                print(f"Some files were changed")
                exit(1)
        except Exception:
            logging.error(traceback.format_exc())
            exit(1)
