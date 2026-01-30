# pipenv.nvim

Pipenv support utilities for Neovim.

---

## Table Of Contents

- [Installation](#installation)
  - [`lazy.nvim`](#lazynvim)
  - [LuaRocks](#luarocks)
- [Configuration](#configuration)
- [Usage](#usage)
- [License](#license)

---

## Installation

### `lazy.nvim`

```lua
{
  'DrKJeff16/pipenv.nvim',
  opts = {},
}
```

### LuaRocks

```bash
luarocks install pipenv.nvim         # Global Install
luarocks install --local pipenv.nvim # Local Install
```

---

## Configuration

WIP! As of writing no setup options are needed.

---

## Usage

You can use the `:Pipenv` command. It can be called with a bang `!` to enable verbose mode.

Some of the subcommands accept any of the following flags:

- `dev=true|false` - The command is called with a `--dev` flag.
- `file=</path/to/file>` - The command output will be written to the target `file`.

| Subcommand             | Nargs | Dev | File | Description                             |
|------------------------|-------|-----|------|-----------------------------------------|
| `:Pipenv help`         | `0`   | [ ] | [ ]  | Prints the usage message                |
| `:Pipenv requirements` | `*`   | [X] | [X]  | Runs `pipenv requirements [--dev]`      |
| `:Pipenv[!] clean`     | `0`   | [ ] | [ ]  | Runs `pipenv clean`                     |
| `:Pipenv[!] install`   | `*`   | [X] | [ ]  | Runs `pipenv install [--dev] [ARGS...]` |
| `:Pipenv[!] lock`      | `0`   | [ ] | [ ]  | Runs `pipenv lock`                      |
| `:Pipenv[!] run`       | `*`   | [ ] | [ ]  | Runs `pipenv run ...`                   |
| `:Pipenv[!] sync`      | `*`   | [X] | [ ]  | Runs `pipenv sync [--dev]`              |

---

## License

[MIT](https://github.com/DrKJeff16/pipenv.nvim/blob/main/LICENSE)

<!-- vim: set ts=2 sts=2 sw=2 et ai si sta: -->
