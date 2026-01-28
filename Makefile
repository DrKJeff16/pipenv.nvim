LUAROCKS_CMD = luarocks install --local

.PHONY: all install-deps test

all: test

install-deps:
	@$(LUAROCKS_CMD) luassert
	@$(LUAROCKS_CMD) busted
	@$(LUAROCKS_CMD) nlua

test: install-deps
	@busted spec

# vim: set ts=4 sts=4 sw=0 noet ai si sta:
