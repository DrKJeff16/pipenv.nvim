TAGS_CMD = nvim --clean --headless -c 'helptags doc/' -c 'qa!'

.PHONY: all format help helptags lint

.SUFFIXES:

all: help

help: ## Show usage
	@echo -e "Usage: make [target]\n\nAvailable targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo

helptags: ## Generate Neovim helptags
	@echo "Generating helptags..."
	@$(TAGS_CMD) > /dev/null 2>&1
	@echo "Done!"

lint: ## Lint with selene
	@echo "Linting with selene..."
	@selene lua
	@echo "Done!"

format: ## Format with StyLua
	@echo "Formatting with StyLua..."
	@stylua .
	@echo "Done!"

# vim: set ts=4 sts=4 sw=0 noet ai si sta:
