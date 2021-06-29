.DEFAULT_GOAL := all

ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
ARGS := $(subst :,\:,$(ARGS))
$(eval $(ARGS):;@:)

include ./Makefile

.PHONY: dev
.SILENT:
.ONESHELL:
dev:: ## Run the Sihl app, watch files and restart on change
	sigint_handler()
	{
	kill -9 $$(lsof -ti tcp:3000)
	exit
	}
	trap sigint_handler SIGINT
	yarn build --log-level 2
	while true; do
	dune build
	if [ $$? -eq 0 ]
	then
		SIHL_ENV=development ./_build/default/run/run.exe server &
	fi
	echo
	inotifywait -e modify -e move -e create -e delete -e attrib -r `pwd` --exclude "(_build|logs|Makefile|.vscode|.devcontainer|.git|.DS_Store|node_modules|resources)" -qq
	kill -9 $$(lsof -ti tcp:3000)
	echo
	done
