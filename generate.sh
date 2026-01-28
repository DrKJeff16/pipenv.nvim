#!/usr/bin/env bash
#
# Generate your plugin data and tweaks with a simple execution!
#

# shellcheck disable=SC2207

DATA=""
MODULE_NAME=""
ANNOTATION_PREFIX=""
LINE_SIZE=""
PLUGIN_NAME=""
PLUGIN_DESCRIPTION=""

OPTIONS=":hv"
VERBOSE=0

# Print all args to `stderr`
_error() {
    local TXT=("$@")
    printf "%s\n" "${TXT[@]}" >&2
    return 0
}

# Only print text if verbose mode is On
_verbose_print() {
    if [[ $VERBOSE -eq 0 ]]; then
        return 0
    fi

    local TXT=("$@")
    printf "%s\n" "${TXT[@]}"
    return 0
}

# Remove with verbose flag if `-v` was passed to script
_verbose_rm() {
    if [[ $VERBOSE -eq 0 ]]; then
        rm -rf "$@" || return 1
        return 0
    fi

    rm -rfv "$@" || return 1
    return 0
}

# Kill the script execution with an exit status and optional messages
_die() {
    local EC=1
    if [[ $# -ge 1 ]] && [[ $1 =~ ^(0|-?[1-9][0-9]*)$ ]]; then
        EC="$1"
        shift
    fi

    if [[ $# -ge 1 ]]; then
        local TXT=("$@")
        if [[ $EC -eq 0 ]]; then
            printf "%s\n" "${TXT[@]}"
        else
            _error "${TXT[@]}"
        fi
    fi

    exit "$EC"
}

# Check whether a given console command exists
_cmd_exists() {
    if [[ $# -eq 0 ]]; then
        _error "What command?"
        return 127
    fi

    local OPTS=":v"
    local VERB=0
    local CMDS=()
    local EXES=()
    local ARG
    while getopts "$OPTS" ARG; do
        case "$ARG" in
            v) VERB=$((VERB + 1)) ;;
            *)
                command -v "$ARG" &> /dev/null || return 1
                CMDS+=("$ARG")
                EXES+=("$(command -v "$ARG" 2> /dev/null)")
                ;;
        esac
        shift
    done

    if [[ $VERB -eq 1 ]]; then
        printf "%s\n" "${CMDS[@]}"
    elif [[ $VERB -eq 2 ]]; then
        printf "\`%s\` ==> OK\n" "${CMDS[@]}"
    elif [[ $VERB -ge 3 ]]; then
        for I in $(seq 1 ${#CMDS[@]}); do
            I=$((I - 1))
            printf "\`%s\` ==> \`%s\` ==> OK\n" "${CMDS[I]}" "${EXES[I]}"
        done
        unset I
    fi
    return 0
}

_usage() {
    local EC=0
    local TXT=()
    if [[ $# -ge 1 ]] && [[ $1 =~ ^(0|-?[1-9][0-9]*)$ ]]; then
        EC="$1"
        shift
    fi
    if [[ $# -ge 1 ]]; then
        TXT+=("$@")
        TXT+=("")
    fi

    TXT+=(
        "generate.sh - Generator script for \`nvim-plugin-boilerplate\`"
        ""
        "Usage: generate.sh [-h] [-v]"
        ""
        "    -h             Print this help message with success exit code"
        "    -v             Enables verbose mode"
        ""
    )
    _die "$EC" "${TXT[@]}"
}

_cmd_exists 'find' || _die 127 "\`find\` / \`sed\` / \`mv\` / \`rm\` not in PATH!"

# Check whether a given file exists, is readable and is writeable aswell
_file_readable_writeable() {
    [[ $# -eq 0 ]] && return 127
    [[ -f "$1" ]] || return 1
    [[ -r "$1" ]] || return 1
    [[ -w "$1" ]] || return 1
    return 0
}

# Check whether a given file exists, is readable and is writeable aswell, plus it is not empty
_file_rw_not_empty() {
    [[ $# -eq 0 ]] && return 127

    _file_readable_writeable "$1" || return 1
    [[ -s "$1" ]] || return 1
    return 0
}

# Generic prompt
_prompt_data() {
    local PROMPT_TXT="$1"
    local ALLOW_EMPTY="$2"
    while true; do
        read -p "$PROMPT_TXT" -r
        case $REPLY in
            "")
                if [[ $ALLOW_EMPTY -eq 1 ]]; then
                    DATA="$REPLY"
                    break
                fi
                ;;
            *)
                DATA="$REPLY"
                break
                ;;
        esac
    done
    return 0
}

# Yes/No prompt
_yn() {
    local PROMPT_TXT="$1"
    local ALLOW_EMPTY="$2"
    local DEFAULT_CHOICE="$3"
    if [[ $ALLOW_EMPTY -eq 1 ]]; then
        case $DEFAULT_CHOICE in
            [Yy] | [Yy][Ee][Ss] | "1") DEFAULT_CHOICE="Y" ;;
            [Nn] | [Nn][Oo] | "0") DEFAULT_CHOICE="N" ;;
            *) DEFAULT_CHOICE="Y" ;;
        esac
    fi

    while true; do
        _prompt_data "$PROMPT_TXT" "$ALLOW_EMPTY"
        if [[ -z "$DATA" ]]; then
            case $DEFAULT_CHOICE in
                "Y") return 0 ;;
                "N") return 1 ;;
            esac
            return 0
        fi
        case $DATA in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) continue ;;
        esac
    done
    return 1
}

# Prompt to rename this module's files
_rename_module() {
    if [[ -d ./lua/my-plugin ]] && _file_readable_writeable "./lua/my-plugin.lua"; then
        while true; do
            _prompt_data "Rename your plugin module (previously: \`my-plugin\`): " 0
            if [[ $DATA =~ ^[a-zA-Z_][a-zA-Z0-9_\-]*[a-zA-Z0-9_]$ ]]; then
                break
            fi
            _error "Invalid module name!" "Use a parseable Lua module name"
        done

        MODULE_NAME="${DATA}"
        mv ./lua/my-plugin "./lua/${MODULE_NAME}" || return 1
        mv ./lua/my-plugin.lua "./lua/${MODULE_NAME}.lua" || return 1
    fi
    if [[ -d ./rplugin/python3 ]] && _file_readable_writeable "./rplugin/python3/my-plugin.py"; then
        mv ./rplugin/python3/my-plugin.py "./rplugin/python3/${MODULE_NAME}.py" || return 1
    fi
    if [[ -d ./spec ]] && _file_readable_writeable "./spec/my-plugin_spec.lua"; then
        mv ./spec/my-plugin_spec.lua "./spec/${MODULE_NAME}_spec.lua" || return 1
    fi
    return 0
}

# Prompt to rename annotation classes
_rename_annotations() {
    local IFS
    while true; do
        _prompt_data "Rename your module class annotations (previously: \`MyPlugin\`): " 0
        if [[ $DATA =~ ^[a-zA-Z][a-zA-Z0-9_\.]*[a-zA-Z0-9_]$ ]]; then
            break
        fi
        _error "Invalid module name: \`${DATA}\`" "Try again..."
    done

    ANNOTATION_PREFIX="${DATA}"
    while IFS= read -r -d '' file; do
        sed -i "s/MyPlugin/${ANNOTATION_PREFIX}/g" "${file}" || return 1
    done < <(find lua -type f -regex '.*\.lua$' -print0)
    while IFS= read -r -d '' file; do
        sed -i "s/my-plugin/${MODULE_NAME}/g" "${file}" || return 1
    done < <(find lua -type f -regex '.*\.lua$' -print0)

    while IFS= read -r -d '' file; do
        sed -i "s/MyPlugin/${ANNOTATION_PREFIX}/g" "${file}" || return 1
    done < <(find spec -type f -regex '.*\.lua$' -print0)
    while IFS= read -r -d '' file; do
        sed -i "s/my-plugin/${MODULE_NAME}/g" "${file}" || return 1
    done < <(find spec -type f -regex '.*_spec\.lua$' -print0)

    while IFS= read -r -d '' file; do
        sed -i "s/MyPlugin/${ANNOTATION_PREFIX}/g" "${file}" || return 1
    done < <(find rplugin -type f -regex '.*\.py$' -print0)

    return 0
}

# Prompt to select the indentation for Lua files
_select_indentation() {
    local IFS
    local ET=""
    DATA=""
    while true; do
        _prompt_data "Use tabs or spaces? [S[paces]/t[abs]]: " 1
        if [[ -z "$DATA" ]]; then
            DATA="Spaces"
            break
        fi
        case "$DATA" in
            [Ss] | [Ss][Pp][Aa][Cc][Ee][Ss])
                DATA="Spaces"
                ET="et"
                break
                ;;
            [Tt] | [Tt][Aa][Bb][Ss])
                DATA="Tabs"
                ET="noet"
                break
                ;;
            *) continue ;;
        esac
    done

    if [[ "$ET" == "noet" ]]; then
        while IFS= read -r -d '' file; do
            sed -i "s/\\set\\s/ ${ET} /g" "${file}" || return 1
        done < <(find lua -type f -regex '.*\.lua$' -print0)
    fi

    if _file_rw_not_empty './stylua.toml'; then
        if grep -E '^indent_type\s+=\s+.*$' ./stylua.toml &> /dev/null; then
            sed -i "s/^indent_type\\s\\+=\\s.*$/indent_type = \"${DATA}\"/g" ./stylua.toml || return 1
        else
            local F_DATA=()
            IFS=$'\n' F_DATA=($(cat ./stylua.toml))
            printf "%s\n" "indent_type = \"${DATA}\"" >| ./stylua.toml
            printf "%s\n" "${F_DATA[@]}" >> ./stylua.toml

            unset F_DATA
        fi
    fi

    while true; do
        _prompt_data "Select your indentation level (default: 2): " 1
        if [[ -z "$DATA" ]]; then
            DATA="2"
            break
        fi
        if ! [[ $DATA =~ ^[1-9]+[0-9]*$ ]]; then
            _error "Invalid indentation level!" "Try again..."
            continue
        fi
        break
    done

    while IFS= read -r -d '' file; do
        sed -i "s/^--\\svim:\\sset\\sts=[1-9]\\+[0-9]*\\ssts=[1-9]\\+[0-9]*\\ssw=[1-9]\\+[0-9]*/-- vim: set ts=${DATA} sts=${DATA} sw=${DATA}/g" "${file}" || return 1
    done < <(find lua -type f -regex '.*\.lua$' -print0)

    if _file_rw_not_empty './stylua.toml'; then
        if grep -E '^indent_width\s+=\s+.*$' ./stylua.toml &> /dev/null; then
            sed -i "s/^indent_width\\s\\+=\\s.*$/indent_width = ${DATA}/g" ./stylua.toml || return 1
        else
            local F_DATA=()
            IFS=$'\n' F_DATA=($(cat ./stylua.toml))
            printf "%s\n" "indent_width = ${DATA}" >| ./stylua.toml
            printf "%s\n" "${F_DATA[@]}" >> ./stylua.toml

            unset F_DATA
        fi
    fi
    return 0
}

# Prompt to select the maximum line size for Lua files
_select_line_size() {
    local IFS
    DATA=""
    while true; do
        _prompt_data "Select your line size (default: 100): " 1
        if [[ -n "$DATA" ]]; then
            if [[ $DATA =~ ^[1-9][0-9]*$ ]]; then
                LINE_SIZE="${DATA}"
                break
            fi
            continue
        fi

        LINE_SIZE="100"
        break
    done

    if _file_rw_not_empty './stylua.toml'; then
        if grep -E '^column_width\s+=\s+.*$' ./stylua.toml &> /dev/null; then
            sed -i "s/^column_width\\s\\+=\\s.*$/column_width = ${LINE_SIZE}/g" ./stylua.toml || return 1
        else
            local F_DATA=()
            IFS=$'\n' F_DATA=($(cat ./stylua.toml))
            printf "%s\n" "column_width = ${LINE_SIZE}" >| ./stylua.toml
            printf "%s\n" "${F_DATA[@]}" >> ./stylua.toml

            unset F_DATA
        fi
    fi
    return 0
}

# Prompt to remove the StyLua config
_remove_stylua() {
    if ! _yn "Remove StyLua config? [y/N]: " 1 "N"; then
        return 0
    fi
    if _file_readable_writeable "./stylua.toml"; then
        _verbose_print "Removing \`stylua.toml\`..." ""
        _verbose_rm ./stylua.toml || return 1
    fi
    if _file_readable_writeable "./.github/workflows/stylua.yml"; then
        _verbose_print "Removing \`.github/workflows/stylua.yml\`..." ""
        _verbose_rm ./.github/workflows/stylua.yml || return 1
    fi
    return 0
}

# Prompt to remove the selene config
_remove_selene() {
    if ! _yn "Remove \`selene\` config? [y/N]: " 1 "N"; then
        return 0
    fi
    if _file_readable_writeable "./selene.toml"; then
        _verbose_print "Removing \`selene.toml\`..." ""
        _verbose_rm ./stylua.toml || return 1
    fi
    if _file_readable_writeable "./vim.yml"; then
        _verbose_print "Removing \`vim.yml\`..." ""
        _verbose_rm ./vim.yml || return 1
    fi
    if _file_readable_writeable "./.github/workflows/selene.yml"; then
        _verbose_print "Removing \`.github/workflows/selene.yml\`..." ""
        _verbose_rm ./.github/workflows/selene.yml || return 1
    fi
    return 0
}

# Prompt to remove the test components
_remove_tests() {
    if ! _yn "Remove tests? [Y/n]: " 1 "Y"; then
        return 0
    fi
    if _file_readable_writeable "./.busted"; then
        _verbose_print "Removing busted config..."
        _verbose_rm ./.busted || return 1
    fi
    if _file_readable_writeable "./Makefile"; then
        _verbose_print "Removing Makefile..."
        _verbose_rm ./Makefile || return 1
    fi
    if [[ -d ./spec ]]; then
        _verbose_print "Removing tests..." ""
        _verbose_rm ./spec || return 1
    fi
    return 0
}

# Prompt to remove the `checkhealth` file
_remove_health_file() {
    if ! _yn "Remove the checkhealth file? [y/N]: " 1 "N"; then
        return 0
    fi
    if _file_readable_writeable "./lua/${MODULE_NAME}/health.lua"; then
        _verbose_print "Removing \`health.lua\`..." ""
        _verbose_rm "./lua/${MODULE_NAME}/health.lua" || return 1
    fi
    return 0
}

# Prompt to remove the Python component
_remove_python_component() {
    if ! _yn "Remove the Python component? [Y/n]: " 1 "Y"; then
        return 0
    fi
    if _file_readable_writeable "./rplugin/python3/${MODULE_NAME}.py"; then
        _verbose_print "Removimg Python component..." ""
        _verbose_rm ./rplugin || return 1
    fi
    return 0
}

# Prompt to remove this script
_remove_script() {
    if ! _file_readable_writeable ./generate.sh; then
        return 1
    fi
    if ! _yn "Self-destruct this script? [Y/n]: " 1 "Y"; then
        _verbose_print "" "This script will need to be deleted again!"
        return 0
    fi

    _verbose_print "Removing this script...\n"
    _verbose_rm ./generate.sh || return 1
    return 0
}

# Rewrite `README.md`
_rewrite_readme() {
    ! _file_readable_writeable "./README.md" && return 1

    _prompt_data "Input the plugin name: " 0
    PLUGIN_NAME="${DATA}"

    _prompt_data "Input the plugin description in one line (markdown syntax): " 1
    PLUGIN_DESCRIPTION="${DATA}"

    local TXT=(
        "# ${PLUGIN_NAME}"
        ""
        "${PLUGIN_DESCRIPTION}"
        ""
        "<!-- vim: set ts=2 sts=2 sw=2 et ai si sta: -->"
    )

    printf "%s\n" "${TXT[@]}" >| ./README.md
    return 0
}

_remove_ci() {
    ! [[ -d ./.github ]] && return 0
    _verbose_rm ./.github/{CODEOWNERS,FUNDING.yml,workflows/vim-eof-comment.yml}
    return $?
}

# Execute the script
_main() {
    _rename_module || _die 1 "Couldn't rename module file structure!"
    _rename_annotations || _die 1 "Couldn't rename module annotations!"

    _select_indentation || _die 1 "Unable to set indentation!"
    _select_line_size || _die 1 "Unable to set StyLua line size!"

    _remove_tests || _die 1 "Unable to (not) remove tests!"
    _remove_health_file || _die 1 "Unable to (not) remove health file!"
    _remove_python_component || _die 1 "Unable to (not) remove Python component!"

    _remove_stylua || _die 1 "Unable to (not) remove StyLua config!"
    _remove_selene || _die 1 "Unable to (not) remove selene config!"

    _remove_ci || _die 1 "Unable to remove useless CI components!"

    _rewrite_readme || _die 1 "Unable to rewrite \`README.md\`!"

    _remove_script || _die 1 "Unable to (not) remove this script!"
    _die 0
}

while getopts "$OPTIONS" OPTION; do
    case "$OPTION" in
        v) VERBOSE=1 ;;
        h) _usage 0 ;;
        :) _usage 1 "Missing argument for option \`${OPTION}\`" ;;
        ?) _usage 1 "Invalid option!" ;;
        *) _usage 1 ;;
    esac
done

_main

# vim: set ts=4 sts=4 sw=4 et ai si sta:
