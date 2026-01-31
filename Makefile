TAGS_CMD = nvim --clean --headless -c 'helptags doc/' -c 'qa!'

.POSIX:

.PHONY: all lint format helptags

.SUFFIXES:

all:
	@echo -e "Usage: make [target]\n\nAvailable targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo

helptags: ## Generate Neovim helptags
	@echo -e "Generating helptags...\n"
	@$(TAGS_CMD) > /dev/null 2>&1

lint: ## Lint with selene
	@echo "Linting with selene..."
	@selene lua
	@echo "Done!"

format: ## Format with StyLua
	@echo "Formatting with StyLua..."
	@stylua .
	@echo "Done!"

# vim: set ts=4 sts=4 sw=0 noet ai si sta:
