# nvim-plugin-boilerplate [![Mentioned in Awesome Neovim](https://awesome.re/mentioned-badge.svg)](https://github.com/rockerBOO/awesome-neovim)

[Codeberg Mirror](https://codeberg.org/DrKJeff16/nvim-plugin-boilerplate) | [GitHub Mirror](https://github.com/DrKJeff16/nvim-plugin-boilerplate)

> [!IMPORTANT]
> **This was NOT AI-generated!**

An annotated Neovim plugin template with `pre-commit`, StyLua and `selene` configs,
with some useful GitHub actions included.

---

## Features

- A dynamic install script [`generate.sh`](https://github.com/DrKJeff16/nvim-plugin-boilerplate/blob/main/generate.sh) (see [Setup](#setup))
- Plenty of utilities you can use with your plugin ([`util.lua`](https://github.com/DrKJeff16/nvim-plugin-boilerplate/blob/main/lua/my-plugin/util.lua))
- Pre-documented Lua code
- Optional template file for `:checkhealth` ([`health.lua`](https://github.com/DrKJeff16/nvim-plugin-boilerplate/blob/main/lua/my-plugin/health.lua))
- Optional Python 3 component ([`rplugin/python3/my-plugin.py`](https://github.com/DrKJeff16/nvim-plugin-boilerplate/blob/main/rplugin/python3/my-plugin.py), DOCUMENTED)
- Optional unit testing using `busted` ([`spec/`](https://github.com/DrKJeff16/nvim-plugin-boilerplate/blob/main/spec/))
- CI utilities supported:
  - `pre-commit` config ([`.pre-commit-config.yaml`](./.pre-commit-config.yaml))
  - StyLua config ([`stylua.toml`](./stylua.toml))
  - `selene` config ([`selene.toml`](./selene.toml), [`vim.yml`](./vim.yml))
  - A bunch of useful GitHub Actions (see [`.github/workflows`](./.github/workflows))

---

## Setup

> [!NOTE]
> The script is subject to breaking changes in the future.
> Therefore please review the instructions below.

To configure the template simply run [`generate.sh`](https://github.com/DrKJeff16/nvim-plugin-boilerplate/blob/main/generate.sh) in your terminal:

```bash
./generate.sh # Has to be run in the repository root!
```

It'll invoke many prompts so that you may structure your plugin as desired.

**The script will delete itself after a successful setup!**

---

## Structure

This template includes the following relevant files:

```
generate.sh  <==  Bash script plugin template generator
stylua.toml  <==  Config file for StyLua
selene.toml  <==  Config file for selene
vim.yml  <==  Std file for selene
.busted  <==  Config file for busted
spec/  <==  Contains all the unit tests
└── my-plugin_spec.lua  <==  NOTE: All test files must end up with `*_spec.lua`!
lua/
├── my-plugin.lua  <==  The main module
├── my-plugin/  <==  Folder containing all the plugin utils
│   ├── config.lua  <==  Configuration module. Contains your main `setup()` function
│   ├── health.lua  <==  Hooks for `:checkhealth` (OPTIONAL)
└   └── util.lua  <==  Utilities for the plugin
rplugin/
├── python3/  <==  Folder containing the Python 3 components
└   └── my-plugin.py  <==  The Python 3 component
.github/
├── workflows/  <==  Folder containing all the GitHub Actions
│   ├── selene.yml  <==  Workflow for selene
└   └── stylua.yml  <==  Workflow for StyLua
```

---

## License

[MIT](./LICENSE)

<!-- vim: set ts=2 sts=2 sw=2 et ai si sta: -->
