#!/bin/sh
# tmux: terminal multiplexer. Ships as a hard dependency of Ubuntu Server's
# own `ubuntu-server` metapackage — confirmed via /var/log/apt/history.log
# on a real box: tmux was installed in the exact same apt transaction as
# ubuntu-server itself, never as a separate later install. So on every box
# this project actually targets, tmux is already present before karl-shell
# ever runs. This module only owns the configuration on top of it, the
# same way git.sh treats git as bedrock rather than something to install.

_tmux_conf="$HOME/.tmux.conf"

install_tmux() {
    require_system_cmd tmux

    cat > "$_tmux_conf" <<'EOF'
# Managed by karl-shell's tmux module — edits here are lost on reinstall.

# tmux waits after Esc by default, in case more keys are coming (part of
# an arrow-key sequence). Near-instant instead — noticeable lag otherwise.
set -sg escape-time 0

# Click to switch panes, drag to resize, scroll to scroll back.
set -g mouse on

# Default scrollback is a tiny 2000 lines.
set -g history-limit 50000

# Windows/panes numbered from 1, not 0 — matches the number row.
set -g base-index 1
setw -g pane-base-index 1

# Keep window numbers contiguous after closing one in the middle.
set -g renumber-windows on

# Correct true-color / 256-color rendering inside tmux.
set -as terminal-features ",*:RGB"
EOF
}

uninstall_tmux() {
    rm -f "$_tmux_conf"
    log "tmux config removed"
}

# Tests this module's own footprint (the config), same as every other
# module — but also requires tmux itself to actually be present, since
# this module has no way to provide it if it's missing.
is_installed_tmux() {
    has_cmd tmux || return 1
    [ -f "$_tmux_conf" ]
}

shell_tmux() {
    :
}