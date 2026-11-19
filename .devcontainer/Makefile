# Devcontainer Makefile — delegates to the workspace root Makefile, so it works
# from any directory inside the container. The database URLs are set in
# docker-compose.yml, because the test binaries read them directly.
#
# Usage (from anywhere inside the container):
#
#   make -f /workspace/.devcontainer/Makefile test
#
# postCreate.sh adds this alias to ~/.zshrc:
#
#   alias make='make -f /workspace/.devcontainer/Makefile'

ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))..

.PHONY: test
test:
	$(MAKE) -C $(ROOT) test

# Forward every other target to the root Makefile unchanged.
.PHONY: %
%:
	$(MAKE) -C $(ROOT) $@
