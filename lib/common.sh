#!/bin/sh
# Shared helpers. Sourced by install.sh, uninstall.sh, shell.sh, and verify.sh.
# Must stay POSIX sh and must never mutate state on its own.

KARL_SHELL_BEGIN='# >>> karl-shell >>>'
KARL_SHELL_END='# <<< karl-shell <<<'
KARL_SHELL_RC_FILES="$HOME/.bashrc $HOME/.profile"
KARL_SHELL_SNAPDIR="/tmp/karl-shell.snapshot.$(id -u)"

# Box-specific values (name/email, etc.) that must never be shared across
# boxes via git. Gitignored; each box has its own copy. Modules that need a
# value from here fail loudly themselves if it's missing — this line only
# loads it when present.
[ -r "$KARL_SHELL_DIR/.env" ] && . "$KARL_SHELL_DIR/.env"

log() { echo "[karl-shell] $*"; }
err() { echo "[karl-shell] ERROR: $*" >&2; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

require_system_cmd() {
    if ! has_cmd "$1"; then
        err "expected system tool '$1' not found. Install it via your package manager first."
        exit 1
    fi
}

# Prepend to PATH only if not already present. Safe to call repeatedly.
path_prepend() {
    case ":${PATH-}:" in
        *":$1:"*) ;;
        *) PATH="$1${PATH:+:$PATH}"; export PATH ;;
    esac
}

# Backstop against third-party installers that edit shell config despite our
# opt-out flags. Whatever they append is discarded at the end of install.
snapshot_rc_files() {
    rm -rf "$KARL_SHELL_SNAPDIR"
    mkdir -p "$KARL_SHELL_SNAPDIR"
    for _sf in $KARL_SHELL_RC_FILES; do
        [ -f "$_sf" ] && cp "$_sf" "$KARL_SHELL_SNAPDIR/$(basename "$_sf")"
    done
}

restore_rc_files() {
    [ -d "$KARL_SHELL_SNAPDIR" ] || return 0
    for _sf in $KARL_SHELL_RC_FILES; do
        _sn="$KARL_SHELL_SNAPDIR/$(basename "$_sf")"
        [ -f "$_sn" ] && cp "$_sn" "$_sf"
    done
    rm -rf "$KARL_SHELL_SNAPDIR"
}

remove_footprint() {
    _cf_file="$1"
    [ -f "$_cf_file" ] || return 0
    grep -qF "$KARL_SHELL_BEGIN" "$_cf_file" || return 0
    sed -i "\%^$KARL_SHELL_BEGIN\$%,\%^$KARL_SHELL_END\$%d" "$_cf_file"
}

write_footprint() {
    _cf_file="$1"
    remove_footprint "$_cf_file"
    {
        echo "$KARL_SHELL_BEGIN"
        echo '[ -f ~/.karl-shell/shell.sh ] && . ~/.karl-shell/shell.sh'
        echo "$KARL_SHELL_END"
    } >> "$_cf_file"
}

reload_shell() {
    [ -n "${KARL_SHELL_NO_EXEC:-}" ] && return 0
    exec bash -l
}

# Module files may carry an optional NN_ prefix to force ordering. The prefix
# is stripped to derive the contract function names, so 01_cargo.sh defines
# install_cargo, not install_01_cargo. Renumbering is a rename, nothing more.
module_name() {
    basename "$1" .sh | sed 's/^[0-9][0-9]*_//'
}

# Modules in LC_ALL=C order: digits sort before letters, so prefixed modules
# run first and unprefixed ones keep their alphabetical order after them.
# Pass "reverse" to iterate backwards — required for uninstall, so a module
# is never torn down before the modules that depend on it.
for_each_module() {
    _fem_action="$1"
    _fem_dir="$2"
    _fem_order="${3:-forward}"
    _fem_list="$(LC_ALL=C ls "$_fem_dir"/modules/*.sh 2>/dev/null)"
    [ -n "$_fem_list" ] || return 0
    if [ "$_fem_order" = "reverse" ]; then
        _fem_list="$(printf '%s\n' "$_fem_list" | LC_ALL=C sort -r)"
    fi
    for _fem_module in $_fem_list; do
        [ -r "$_fem_module" ] || continue
        _fem_name="$(module_name "$_fem_module")"
        (
            . "$_fem_dir/lib/common.sh"
            . "$_fem_module"
            for _fem_fn in install uninstall is_installed shell; do
                command -v "${_fem_fn}_$_fem_name" >/dev/null 2>&1 || {
                    err "$(basename "$_fem_module"): missing ${_fem_fn}_$_fem_name"
                    exit 1
                }
            done
            "$_fem_action" "$_fem_name"
        ) || return 1
    done
    return 0
}