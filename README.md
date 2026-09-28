.karl-shell
===========

Per-user dev environment bootstrap. No sudo, no writes outside $HOME,
fully reversible.

Usage
-----

git clone <repo> ~/.karl-shell
cp ~/.karl-shell/.env.example ~/.karl-shell/.env
edit ~/.karl-shell/.env with this box's values (see "Box-specific config" below)

~/.karl-shell/install.sh
exec bash -l          (or open a new terminal)

~/.karl-shell/uninstall.sh
~/.karl-shell/verify.sh   (round-trip test)

Box-specific config
--------------------

Some values legitimately differ per box - for example, git identity: work
boxes use a work email, personal boxes use a personal one. These can never
live in a tracked module file, since every box shares the same git history;
whatever value got committed would overwrite every other box's value on the
next pull.

Instead, they live in .env at the repo root - plain sh variable
assignments, gitignored, never committed, never shared between boxes.
lib/common.sh sources it automatically if present, before any module runs,
so any module can read a KARL_SHELL_* variable from it. .env.example is
the tracked template: it lists every variable any module currently expects,
with placeholder values, so setting up a new box means copying it and
filling in real values once, rather than discovering each required variable
one failed install at a time.

A module that needs a box-specific value fails loudly if it's missing or
empty, rather than falling back to some default - same as any other missing
dependency in this project.

Layout
------

install.sh      drives install_* across modules, writes the .bashrc footprint
uninstall.sh    drives uninstall_* across modules, removes the footprint
shell.sh        sourced by .bashrc; drives shell_* for installed modules
verify.sh       install/uninstall round-trip assertions
lib/common.sh   shared helpers (log, has_cmd, path_prepend, footprint I/O);
                also sources .env if present
modules/*.sh    one file per tool
.env.example    tracked template for box-specific values - copy to .env
.env            gitignored, box-specific, created locally per box

install.sh and uninstall.sh write exactly one sentinel block to ~/.bashrc:

  >>> karl-shell >>>
  [ -f ~/.karl-shell/shell.sh ] && . ~/.karl-shell/shell.sh
  <<< karl-shell <

Both operations strip any existing block before acting, so repeated runs are
byte-idempotent.

Module contract
----------------

A module modules/<name>.sh defines exactly four functions and nothing else
at top level. Module-local variables are prefixed _<name>_.

  Function              Contract
  install_<name>         Installs under $HOME only. Calls require_system_cmd
                          for each of its own system deps.
  uninstall_<name>       Fully reverts install_<name>. Afterwards
                          is_installed_<name> must be false.
  is_installed_<name>    Tests this module's own footprint, not merely
                          whether a binary is on PATH.
  shell_<name>           Per-shell setup only. Idempotent under repeated
                          sourcing.

Rules:

1. Isolation. A module assumes no other module exists. If it needs
   ~/.local/bin on PATH, it calls path_prepend itself.

2. No shell-config writes. Modules never touch ~/.bashrc, ~/.profile,
   ~/.zshrc. Pass the upstream installer's opt-out
   (PROFILE=/dev/null, INSTALLER_NO_MODIFY_PATH=1) instead.

3. shell_* mutates nothing persistent. No git config --global, no file
   writes, no network. Persistent config belongs in install_* and must be
   undone in uninstall_*.

4. No sudo, no /usr/local. Everything lands under $HOME.

5. Fail loudly. Don't blanket- || true a rm; only guard commands that
   are genuinely allowed to fail.

6. Box-specific values never live in the module itself. If a value
   legitimately differs per box (git identity, etc.), it comes from .env
   (see "Box-specific config" above) via a KARL_SHELL_* variable, and the
   module fails loudly if it's unset.

Modules are sourced and invoked in subshells, so they cannot leak variables
into each other or into the driver scripts.

Run verify.sh after adding a module.