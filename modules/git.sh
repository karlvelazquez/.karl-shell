#!/bin/sh
# git: system-provided. This module owns only the three global config keys
# it sets; --unset is their exact inverse. No bookkeeping files.
#
# Name/email are box-specific (personal vs work boxes use different
# addresses) and come from $KARL_SHELL_DIR/.env, which is gitignored and
# never shared between boxes — see common.sh, which sources it if present.
# install_git fails loudly if either value is missing, rather than silently
# falling back to some default identity.

_git_name="${KARL_SHELL_GIT_NAME:-}"
_git_email="${KARL_SHELL_GIT_EMAIL:-}"

install_git() {
    require_system_cmd git

    if [ -z "$_git_name" ] || [ -z "$_git_email" ]; then
        err "git: KARL_SHELL_GIT_NAME/KARL_SHELL_GIT_EMAIL not set — create $KARL_SHELL_DIR/.env (see .env.example)"
        exit 1
    fi

    git config --global user.name "$_git_name"
    git config --global user.email "$_git_email"
    git config --global color.ui auto
}

uninstall_git() {
    git config --global --unset user.name  || true
    git config --global --unset user.email || true
    git config --global --unset color.ui   || true
    # --unset leaves an empty file behind; skel has no .gitconfig.
    [ -f "$HOME/.gitconfig" ] && [ ! -s "$HOME/.gitconfig" ] && rm -f "$HOME/.gitconfig"
    log "git config reverted"
}

# Tests this module's own footprint, not merely whether git exists on PATH.
# Guards on _git_email being non-empty first: without that, an empty
# expected value could accidentally match an equally-unset git config and
# falsely report "installed" when .env was never actually set up.
is_installed_git() {
    has_cmd git || return 1
    [ -n "$_git_email" ] || return 1
    [ "$(git config --global --get user.email 2>/dev/null || true)" = "$_git_email" ]
}

shell_git() {
    alias gl='git log --oneline --graph --all --decorate'
}