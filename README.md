# pipenv.nvim

Manage your Pipenv environment from within Neovim.

https://github.com/user-attachments/assets/e5697041-c01f-4eae-887b-d9277022186e

---

## Table Of Contents

- [Installation](#installation)
  - [`lazy.nvim`](#lazynvim)
  - [LuaRocks](#luarocks)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Without Subcommands](#without-subcommands)
  - [With Subcommands](#with-subcommands)
- [API](#api)
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

These are the default options:

```lua
require('pipenv').setup({
  output = {
    width = 0.85, -- Can be a number between `0` and `1` (percentage) or a fixed width
    height = 0.85, -- Can be a number between `0` and `1` (percentage) or a fixed height
    zindex = 100, -- The `zindex` value of the output window
  },
  python_version = nil, -- Can be `nil` or a string containing the Python version (e.g. '3.10')
})
```

---

## Usage

You can use the `:Pipenv` command to do certain operations with Pipenv from within Neovim.

To enable verbose mode in any operation simply add a `!` to the command (`:Pipenv!`).

You can also pass these flags:

- `dev=true|false` - The command is called with a `--dev` flag.
- `file=</path/to/file>` - The command output will be written to the target `file`.
- `python=<PYTHON_VERSION>` - The python version for Pipenv to use. Must be formatted correctly
  (e.g. `python=3.10`, `python=3.13`, ...)

Keep in mind that any flag that doesn't get parsed by a subcommand can still be passed,
only it won't make a difference!

The valid subcommands are:

- `clean`
- `edit`
- `graph`
- `help`
- `install`
- `list-installed`
- `lock`
- `requirements`
- `run`
- `scripts`
- `sync`
- `uninstall`
- `verify`

### Without Subcommands

<table>
  <tr>
    <td>
      <p align="center">
        <img alt="Showcase" src="https://github.com/user-attachments/assets/ff2d08f6-f70d-4dd4-9ea4-df18a78a9a56" /><br />
        <em>The UI spawned when running without subcommands.</em>
      </p>
    </td>
  </tr>
</table>

You can run `:Pipenv[!]` without any of the subcommands listed above. This will open a UI
prompting to do any of the valid Pipenv operations.

Keep in mind flags can still be passed to achieve the same effect
for any operation that requires it.

Examples:

```vim
:Pipenv                               " verbose=false, dev=false, file=nil, python=nil
:Pipenv python=3.10                   " verbose=false, dev=false, file=nil, python=3.10
:Pipenv!                              " verbose=true, dev=false, file=nil, python=nil
:Pipenv! dev=true file=/path/to/file  " verbose=true, dev=true, file=/path/to/file, python=nil
```

### With Subcommands

Below is a table specifying what flags are parsed.

| Subcommand       | Nargs         | Verbose (`!`) | Dev | File | Python | Description                                             |
|------------------|---------------|---------------|-----|------|--------|---------------------------------------------------------|
| `help`           | `0`           | [ ]           | [ ] | [ ]  | [ ]    | Prints the usage message                                |
| `edit`           | `0`           | [ ]           | [ ] | [ ]  | [ ]    | Edit the `Pipfile` or create a blank one if none exists |
| `list-installed` | `0`           | [ ]           | [ ] | [ ]  | [ ]    | Lists the installed packages in a window                |
| `scripts`        | `0`           | [ ]           | [ ] | [ ]  | [ ]    | Lists the defined scripts in the Pipfile                |
| `graph`          | `0`           | [ ]           | [ ] | [ ]  | [X]    | Returns the output of `pipenv graph`                    |
| `clean`          | `0`           | [X]           | [ ] | [ ]  | [X]    | Runs `pipenv clean`                                     |
| `install`        | `*`           | [X]           | [X] | [ ]  | [X]    | Runs `pipenv install [--dev] [ARGS...]`                 |
| `lock`           | `0`           | [X]           | [ ] | [ ]  | [X]    | Runs `pipenv lock`                                      |
| `requirements`   | `*`           | [X]           | [X] | [X]  | [X]    | Runs `pipenv requirements [--dev]`                      |
| `run`            | `1` or more   | [X]           | [ ] | [ ]  | [X]    | Runs `pipenv run ...`                                   |
| `sync`           | `*`           | [X]           | [X] | [ ]  | [X]    | Runs `pipenv sync [--dev]`                              |
| `uninstall`      | `*`           | [X]           | [X] | [ ]  | [X]    | Runs `pipenv uninstall [--dev] [ARGS...]`               |
| `verify`         | `0`           | [X]           | [ ] | [ ]  | [X]    | Runs `pipenv verify`                                    |


Examples:

```vim
:Pipenv run <COMMANDS>                            " verbose=false
:Pipenv! run <COMMANDS>                           " verbose=true

:Pipenv! edit                                     " The verbose flag doesn't matter

:Pipenv! sync dev=true                            " verbose=true, dev=false
:Pipenv! dev=true sync                            " Same as above

:Pipenv! python=3.13 install <PACKAGES>            " verbose=true, python=3.13

:Pipenv dev=true file=/path/to/file requirements  " verbose=false, dev=true, file=/path/to/file
```

---

## API

Most of the API is publicly available on the main module
(see [api.lua](https://github.com/DrKJeff16/pipenv.nvim/blob/main/lua/pipenv/api.lua)).
It contains all the operations used by the `:Pipenv` user command.

| Function               | Used By                  |
|------------------------|--------------------------|
| `Api.clean()`          | `:Pipenv clean`          |
| `Api.graph()`          | `:Pipenv graph`          |
| `Api.install()`        | `:Pipenv install`        |
| `Api.list_installed()` | `:Pipenv list-installed` |
| `Api.lock()`           | `:Pipenv lock`           |
| `Api.requirements()`   | `:Pipenv requirements`   |
| `Api.run()`            | `:Pipenv run`            |
| `Api.sync()`           | `:Pipenv sync`           |
| `Api.uninstall()`      | `:Pipenv uninstall`      |
| `Api.verify()`         | `:Pipenv verify`         |

---

## License

[MIT](https://github.com/DrKJeff16/pipenv.nvim/blob/main/LICENSE)

<!-- vim: set ts=2 sts=2 sw=2 et ai si sta: -->
