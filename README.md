# pipenv.nvim

Manage your Pipenv environment from within Neovim.

https://github.com/user-attachments/assets/e5697041-c01f-4eae-887b-d9277022186e

---

## Table Of Contents

- [Installation](#installation)
  - [`lazy.nvim`](#lazynvim)
  - [`pckr.nvim`](#pckrnvim)
  - [`paq-nvim`](#paq-nvim)
  - [LuaRocks](#luarocks)
- [Configuration](#configuration)
  - [Customizing Pipenv](#customizing-pipenv)
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

### `pckr.nvim`

```lua
require('pckr').add({
  {
    'DrKJeff16/pipenv.nvim',
    config = function()
      require('pipenv').setup()
    end,
  },
})
```

### `paq-nvim`

```lua
local paq = require('paq')
paq({ 'DrKJeff16/pipenv.nvim' })
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
  -- Output window options (`:Pipenv!`)
  output = {
    width = 0.85, -- Can be a number between `0` and `1` (percentage) or a fixed width
    height = 0.85, -- Can be a number between `0` and `1` (percentage) or a fixed height
    zindex = 100, -- The `zindex` value of the output window
  },
  env = { -- See the `Customizing Pipenv` section
    install = {},
    virtual_env = {},
    file_location = {},
    security = {},
    behavior = {},
  },
})
```

### Customizing Pipenv

You can customize the environment variables used when executing Pipenv operations.
By default no option is set as to not interfere with your environment variables.

See the [Pipenv Documentation](https://pipenv.pypa.io/en/latest/configuration.html#available-environment-variables) for more info.


| Setup Option                          | Type      | Environment Variable            |
|---------------------------------------|-----------|---------------------------------|
| `env.behavior.auto_accept`            | `boolean` | `PIPENV_YES`                    |
| `env.behavior.clear_cache`            | `boolean` | `PIPENV_CLEAR`                  |
| `env.behavior.fancy_shell`            | `boolean` | `PIPENV_SHELL_FANCY`            |
| `env.behavior.ignore_pipfile`         | `boolean` | `PIPENV_IGNORE_PIPFILE`         |
| `env.behavior.no_asdf`                | `boolean` | `PIPENV_DONT_USE_ASDF`          |
| `env.behavior.no_load_env`            | `boolean` | `PIPENV_DONT_LOAD_ENV`          |
| `env.behavior.no_pyenv`               | `boolean` | `PIPENV_DONT_USE_PYENV`         |
| `env.behavior.no_spin`                | `boolean` | `PIPENV_NOSPIN`                 |
| `env.behavior.quiet`                  | `boolean` | `PIPENV_QUIET`                  |
| `env.behavior.requests_timeout`       | `number`  | `PIPENV_REQUESTS_TIMEOUT`       |
| `env.behavior.site_packages`          | `boolean` | `PIPENV_SITE_PACKAGES`          |
| `env.behavior.verbose`                | `boolean` | `PIPENV_VERBOSE`                |
| `env.file_location.cache_dir`         | `string`  | `PIPENV_CACHE_DIR`              |
| `env.file_location.dotenv_location`   | `string`  | `PIPENV_DOTENV_LOCATION`        |
| `env.file_location.pipfile_path`      | `string`  | `PIPENV_PIPFILE`                |
| `env.install.install_dependencies`    | `boolean` | `PIPENV_INSTALL_DEPENDENCIES`   |
| `env.install.install_timeout`         | `number`  | `PIPENV_INSTALL_TIMEOUT`        |
| `env.install.max_depth`               | `number`  | `PIPENV_MAX_DEPTH`              |
| `env.install.pypi_mirror`             | `string`  | `PIPENV_PYPI_MIRROR`            |
| `env.install.resolve_vcs`             | `boolean` | `PIPENV_RESOLVE_VCS`            |
| `env.install.skip_lock`               | `boolean` | `PIPENV_SKIP_LOCK`              |
| `env.install.timeout`                 | `number`  | `PIPENV_TIMEOUT`                |
| `env.security.pyup_api_key`           | `string`  | `PIPENV_PYUP_API_KEY`           |
| `env.virtual_env.ignore_virtual_envs` | `boolean` | `PIPENV_IGNORE_VIRTUALENVS`     |
| `env.virtual_env.python_path`         | `string`  | `PIPENV_PYTHON`                 |
| `env.virtual_env.python_version`      | `string`  | `PIPENV_DEFAULT_PYTHON_VERSION` |
| `env.virtual_env.venv_in_project`     | `boolean` | `PIPENV_VENV_IN_PROJECT`        |
| `env.virtual_env.venv_name`           | `string`  | `PIPENV_CUSTOM_VENV_NAME`       |
| `env.virtual_env.venv_path`           | `string`  | `PIPENV_VIRTUALENV`             |

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
        <img
        alt="Showcase"
        src="https://github.com/user-attachments/assets/ff2d08f6-f70d-4dd4-9ea4-df18a78a9a56"
        />
        <br />
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

| Subcommand       | Nargs         | Verbose | Dev | File | Python | Description                                                    |
|------------------|---------------|---------|-----|------|--------|----------------------------------------------------------------|
| `help`           | `0`           | [ ]     | [ ] | [ ]  | [ ]    | Prints the usage message                                       |
| `edit`           | `0`           | [ ]     | [ ] | [ ]  | [ ]    | Edit the `Pipfile` or create a blank one if none exists        |
| `list-installed` | `0`           | [ ]     | [ ] | [ ]  | [ ]    | Lists the installed packages in a window                       |
| `scripts`        | `0`           | [ ]     | [ ] | [ ]  | [ ]    | Lists the defined scripts in the Pipfile                       |
| `graph`          | `0`           | [ ]     | [ ] | [ ]  | [X]    | Returns the output of `pipenv [--python <VERSION>] graph`      |
| `clean`          | `0`           | [X]     | [ ] | [ ]  | [X]    | Runs `pipenv [--python <VERSION>] clean`                       |
| `install`        | `*`           | [X]     | [X] | [ ]  | [X]    | Runs `pipenv [--python <VERSION>] install [--dev] [ARGS...]`   |
| `lock`           | `0`           | [X]     | [ ] | [ ]  | [X]    | Runs `pipenv [--python <VERSION>] lock`                        |
| `requirements`   | `*`           | [X]     | [X] | [X]  | [X]    | Runs `pipenv [--python <VERSION>] requirements [--dev]`        |
| `run`            | `1` or more   | [X]     | [ ] | [ ]  | [X]    | Runs `pipenv [--python <VERSION>] run ...`                     |
| `sync`           | `*`           | [X]     | [X] | [ ]  | [X]    | Runs `pipenv [--python <VERSION>] sync [--dev]`                |
| `uninstall`      | `*`           | [X]     | [X] | [ ]  | [X]    | Runs `pipenv [--python <VERSION>] uninstall [--dev] [ARGS...]` |
| `verify`         | `0`           | [X]     | [ ] | [ ]  | [X]    | Runs `pipenv [--python <VERSION>] verify`                      |


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
[`pipenv.lua`](https://github.com/DrKJeff16/pipenv.nvim/blob/main/lua/pipenv.lua), which imports the
utilities from [`core.lua`](https://github.com/DrKJeff16/pipenv.nvim/blob/main/lua/pipenv/core.lua).

The operations used by the `:Pipenv` user command are the following:

| Subcommand               | Core Function Called                      |
|--------------------------|-------------------------------------------|
| `:Pipenv clean`          | `require('pipenv.core').clean()`          |
| `:Pipenv edit`           | `require('pipenv.core').edit()`           |
| `:Pipenv graph`          | `require('pipenv.core').graph()`          |
| `:Pipenv install`        | `require('pipenv.core').install()`        |
| `:Pipenv list-installed` | `require('pipenv.core').list_installed()` |
| `:Pipenv scripts`        | `require('pipenv.core').list_scripts()`   |
| `:Pipenv lock`           | `require('pipenv.core').lock()`           |
| `:Pipenv requirements`   | `require('pipenv.core').requirements()`   |
| `:Pipenv run`            | `require('pipenv.core').run()`            |
| `:Pipenv sync`           | `require('pipenv.core').sync()`           |
| `:Pipenv uninstall`      | `require('pipenv.core').uninstall()`      |
| `:Pipenv verify`         | `require('pipenv.core').verify()`         |

---

## License

[MIT](https://github.com/DrKJeff16/pipenv.nvim/blob/main/LICENSE)

<!-- vim: set ts=2 sts=2 sw=2 et ai si sta: -->
