#!/bin/sh
# uv: installed to ~/.local/bin. Env vars go on the right side of the pipe —
# that's the process that reads them. PATH is our job, in shell_uv.
#
# INSTALLER_NO_MODIFY_PATH suppresses rc-file PATH edits but NOT the installer
# receipt, the fish integration, or the env shims — those are removed explicitly.

_uv_bin_dir="$HOME/.local/bin"
_uv_bin="$_uv_bin_dir/uv"

install_uv() {
    require_system_cmd curl
    curl -LsSf https://astral.sh/uv/install.sh \
        | INSTALLER_NO_MODIFY_PATH=1 UV_INSTALL_DIR="$_uv_bin_dir" sh
}

uninstall_uv() {
    if [ -x "$_uv_bin" ]; then
        # --force: without it, this blocks indefinitely if another uv
        # process holds the cache lock, instead of just failing fast.
        "$_uv_bin" cache clean --force --cache-dir "$HOME/.cache/uv" || true
        _uv_py="$("$_uv_bin" python dir 2>/dev/null || true)"
        _uv_tool="$("$_uv_bin" tool dir 2>/dev/null || true)"
        [ -n "$_uv_py" ]   && [ -d "$_uv_py" ]   && rm -rf "$_uv_py"
        [ -n "$_uv_tool" ] && [ -d "$_uv_tool" ] && rm -rf "$_uv_tool"
    fi
    rm -rf "$HOME/.local/share/uv" "$HOME/.cache/uv" "$HOME/.config/uv"
    rm -f "$_uv_bin" "$_uv_bin_dir/uvx"
    # Shell shims the installer writes regardless of INSTALLER_NO_MODIFY_PATH.
    rm -f "$_uv_bin_dir/env" "$_uv_bin_dir/env.fish"
    rm -f "$HOME/.config/fish/conf.d/uv.env.fish"
    # Only if we emptied it — fish may be someone else's.
    rmdir "$HOME/.config/fish/conf.d" "$HOME/.config/fish" 2>/dev/null || true
    log "uv removed"
}

# Also checks the env shim, not just the binary: it's part of this module's
# own footprint (uninstall_uv explicitly removes it), so if it goes missing
# independently of the binary, install.sh should notice and repair it rather
# than silently reporting "already installed" on a half-complete state.
is_installed_uv() {
    [ -x "$_uv_bin" ] || return 1
    [ -f "$_uv_bin_dir/env" ]
}

shell_uv() {
    path_prepend "$_uv_bin_dir"
}