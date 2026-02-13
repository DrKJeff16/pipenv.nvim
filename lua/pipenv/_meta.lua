---@meta
---@diagnostic disable:unused-local

---@module 'spinner'
---@module 'job'

---@class PipenvSpinner
---@field id string
---@field text string
---@field start fun(self: PipenvSpinner)
---@field stop fun(self: PipenvSpinner, force?: boolean)
---@field pause fun(self: PipenvSpinner, force?: boolean)

---@class Pipenv.CommandOpts: JobOpts

---Options for customizing your spinner.
---
---See https://github.com/xieyonn/spinner.nvim for more info about these options
--- ---
---@class PipenvSpinner.Opts
---@field attach? { text: string, status: PipenvOpts.SpinnerEventStatus }
---@field border? string|PipenvWinBorders
---@field bufnr? integer
---@field col? integer
---@field fmt? fun(event: { text: string, status: PipenvOpts.SpinnerEventStatus }): string
---@field hl_group? string
---@field initial_delay_ms? integer
---@field kind? PipenvOpts.SpinnerKind
---@field ns? integer
---@field on_update_ui? fun(event: { text: string, status: PipenvOpts.SpinnerEventStatus })
---@field pattern? PipenvOpts.SpinnerPattern
---@field placeholder? boolean|string
---@field row? integer
---@field ttl_ms? integer
---@field ui_scope? string
---@field winblend? integer
---@field zindex? integer

---Options for customizing the `spinner.nvim` integration.
--- ---
---@class PipenvOpts.Spinner
---If `true` it will add a spinner while an operation is running.
---
---If `spinner.nvim` is not installed this will raise a warning and be ignored.
--- ---
---@field enabled? boolean
---Options for customizing your spinner.
---
---See https://github.com/xieyonn/spinner.nvim for more info about these options
--- ---
---@field opts? PipenvSpinner.Opts|spinner.Opts

---@class PipenvOpts.Output
---Can be a number between `0` and `1` (percentage) or a fixed width (only matters if `float` is `true`).
--- ---
---@field width? number
---Can be a number between `0` and `1` (percentage) or a fixed height (only matters if `float` is `true`).
--- ---
---@field height? number
---The `zindex` value of the output window (only matters if `float` is `true`).
--- ---
---@field zindex? integer
---Whether the output window should be a float or not.
--- ---
---@field float? boolean
---In what direction should the window be split (only matters if `float` is `false`).
--- ---
---@field split? 'right'|'left'|'above'|'below'
---The border type for the floating window (only matters if `float` is `true`).
--- ---
---@field border? 'none'|'single'|'double'|'rounded'|'solid'|'shadow'

---For more info see https://pipenv.pypa.io/en/latest/configuration.html#installation-and-dependencies
--- ---
---@class PipenvOpts.Env.InstallAndDeps
---If `false` then `$PIPENV_INSTALL_DEPENDENCIES` will be set to `0`.
--- ---
---@field install_dependencies? boolean
---If `false` then `$PIPENV_RESOLVE_VCS` will be set to `0`.
--- ---
---@field resolve_vcs? boolean
---If `true` then `$PIPENV_SKIP_LOCK` will be set to `1`.
--- ---
---@field skip_lock? boolean
---If non-nil then `$PIPENV_PYPI_MIRROR` will be set to its value.
--- ---
---@field pypi_mirror? string
---Will set `$PIPENV_MAX_DEPTH` to its value.
--- ---
---@field max_depth? integer
---Will set `$PIPENV_INSTALL_TIMEOUT` to its value.
--- ---
---@field install_timeout? integer
---Will set `$PIPENV_TIMEOUT` to its value.
--- ---
---@field timeout? integer

---For more info see https://pipenv.pypa.io/en/latest/configuration.html#virtual-environment
--- ---
---@class PipenvOpts.Env.VirtualEnv
---If `true` then `$PIPENV_IGNORE_VIRTUALENVS` will be set to `1`.
--- ---
---@field ignore_virtual_envs? boolean
---If non-nil then `$PIPENV_PYTHON` will be set to its value.
--- ---
---@field python_path? string
---If non-nil then `$PIPENV_DEFAULT_PYTHON_VERSION` will be set to its value.
--- ---
---@field python_version? string
---If `true` then `$PIPENV_VENV_IN_PROJECT` will be set to `1`.
--- ---
---@field venv_in_project? boolean
---If non-nil then `$PIPENV_CUSTOM_VENV_NAME` will be set to its value.
--- ---
---@field venv_name? string
---If non-nil then `$PIPENV_VIRTUALENV` will be set to its value.
--- ---
---@field venv_path? string

---For more info see https://pipenv.pypa.io/en/latest/configuration.html#security
--- ---
---@class PipenvOpts.Env.Security
---If non-nil then `$PIPENV_PYUP_Core_KEY` will be set to its value.
--- ---
---@field pyup_api_key? string

---For more info see https://pipenv.pypa.io/en/latest/configuration.html#file-locations
--- ---
---@class PipenvOpts.Env.Behavior
---If `true` then `$PIPENV_DONT_LOAD_ENV` will be set to `1`.
--- ---
---@field no_load_env? boolean
---If `true` then `$PIPENV_DONT_USE_PYENV` will be set to `1`.
--- ---
---@field no_pyenv? boolean
---If `true` then `$PIPENV_DONT_USE_ASDF` will be set to `1`.
--- ---
---@field no_asdf? boolean
---If `true` then `$PIPENV_SHELL_FANCY` will be set to `1`.
--- ---
---@field fancy_shell? boolean
---If `true` then `$PIPENV_NOSPIN` will be set to `1`.
--- ---
---@field no_spin? boolean
---If `true` then `$PIPENV_QUIET` will be set to `1`.
--- ---
---@field quiet? boolean
---If `true` then `$PIPENV_VERBOSE` will be set to `1`.
--- ---
---@field verbose? boolean
---If `true` then `$PIPENV_YES` will be set to `1`.
--- ---
---@field auto_accept? boolean
---If `true` then `$PIPENV_IGNORE_PIPFILE` will be set to `1`.
--- ---
---@field ignore_pipfile? boolean
---Will set `$PIPENV_REQUESTS_TIMEOUT` to its value.
--- ---
---@field timeout? integer
---If `true` then `$PIPENV_CLEAR` will be set to `1`.
--- ---
---@field clear_cache? boolean
---If `true` then `$PIPENV_SITE_PACKAGES` will be set to `1`.
--- ---
---@field site_packages? boolean

---For more info see https://pipenv.pypa.io/en/latest/configuration.html#file-locations
--- ---
---@class PipenvOpts.Env.FileLocations
---If non-nil then `$PIPENV_CACHE_DIR` will be set to its value.
--- ---
---@field cache_dir? string
---If non-nil then `$PIPENV_PIPFILE` will be set to its value.
--- ---
---@field pipfile_path? string
---If non-nil then `$PIPENV_DOTENV_LOCATION` will be set to its value.
--- ---
---@field dotenv_location? string

---@class PipenvOpts.Env
---@field install? PipenvOpts.Env.InstallAndDeps
---@field virtual_env? PipenvOpts.Env.VirtualEnv
---@field file_location? PipenvOpts.Env.FileLocations
---@field behavior? PipenvOpts.Env.Behavior
---@field security? PipenvOpts.Env.Security

---@class Pipenv.CommandOpts
---@field verbose? boolean
---@field python? string

---@class Pipenv.RequirementsOpts
---@field verbose? boolean
---@field dev? boolean
---@field file? string[]|string|nil
---@field python? string

---@class Pipenv.RemoveOpts
---@field verbose? boolean

---@class Pipenv.GraphOpts
---@field python? string

---@class Pipenv.SyncOpts: Pipenv.CommandOpts
---@field dev? boolean
---@field pre? boolean

---@class Pipenv.UpgradeOpts: Pipenv.SyncOpts
---@class Pipenv.UpdateOpts: Pipenv.SyncOpts

---@class Pipenv.CleanOpts: Pipenv.CommandOpts
---@class Pipenv.InstallOpts: Pipenv.SyncOpts
---@class Pipenv.LockOpts: Pipenv.SyncOpts
---@class Pipenv.RunOpts: Pipenv.CommandOpts
---@class Pipenv.ScriptsOpts: Pipenv.GraphOpts
---@class Pipenv.UninstallOpts: Pipenv.SyncOpts
---@class Pipenv.VerifyOpts: Pipenv.CommandOpts

---@class PipenvJsonPackage
---@field key string
---@field package_name string
---@field installed_version string

---@alias PipenvJsonGraph table<'package', PipenvJsonPackage>

---@enum (key) PipenvOpts.SpinnerPattern
local patterns = {
  aesthetic = 1,
  arc = 1,
  arrow = 1,
  arrow3 = 1,
  balloon = 1,
  balloon2 = 1,
  betaWave = 1,
  binary = 1,
  bounce = 1,
  bouncingBall = 1,
  bouncingBar = 1,
  boxBounce = 1,
  boxBounce2 = 1,
  circle = 1,
  circleHalves = 1,
  circleQuarters = 1,
  dots = 1,
  dots10 = 1,
  dots11 = 1,
  dots12 = 1,
  dots13 = 1,
  dots14 = 1,
  dots2 = 1,
  dots3 = 1,
  dots4 = 1,
  dots5 = 1,
  dots6 = 1,
  dots7 = 1,
  dots8 = 1,
  dots8Bit = 1,
  dots9 = 1,
  dotsCircle = 1,
  dqpb = 1,
  dwarfFortress = 1,
  fish = 1,
  flip = 1,
  grenade = 1,
  growHorizontal = 1,
  growVertical = 1,
  hamburger = 1,
  layer = 1,
  line = 1,
  line2 = 1,
  material = 1,
  noise = 1,
  pipe = 1,
  point = 1,
  pong = 1,
  rollingLine = 1,
  sand = 1,
  shark = 1,
  simpleDots = 1,
  simpleDotsScrolling = 1,
  squareCorners = 1,
  squish = 1,
  star = 1,
  star2 = 1,
  toggle = 1,
  toggle10 = 1,
  toggle11 = 1,
  toggle12 = 1,
  toggle13 = 1,
  toggle2 = 1,
  toggle3 = 1,
  toggle4 = 1,
  toggle5 = 1,
  toggle6 = 1,
  toggle7 = 1,
  toggle8 = 1,
  toggle9 = 1,
  triangle = 1,
}

---@enum (key) PipenvOpts.SpinnerEventStatus
local spinner_status = {
  delayed = 1,
  paused = 1,
  running = 1,
  stopped = 1,
}

---@enum (key) PipenvOpts.SpinnerKind
local kinds = {
  ['window-footer'] = 1,
  ['window-title'] = 1,
  cmdline = 1,
  cursor = 1,
  extmark = 1,
  statusline = 1,
  tabline = 1,
  winbar = 1,
}

---@enum (key) PipenvWinBorders
local borders = {
  bold = 1,
  double = 1,
  none = 1,
  rounded = 1,
  shadow = 1,
  single = 1,
  solid = 1,
}

-- vim: set ts=2 sts=2 sw=2 et ai si sta:
