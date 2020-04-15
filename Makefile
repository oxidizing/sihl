# The name of your project (as given in the dune-project file)
# TODO
project_name = ocaml_webapp

# The opam package configuration file
opam_file = $(project_name).opam

.PHONY: deps run run-debug migrate rollback

# Alis to update the opam file and install the needed deps
deps: $(opam_file)

# Build and run the app
run:
	dune exec $(project_name)

# Build and run the app with Opium's internal debug messages visible
run-debug:
	dune exec $(project_name) -- --debug

# Run the database migrations defined in migrate/migrate.ml
migrate:
	dune exec migrate_ocaml_webapp

# Run the database rollback defined in migrate/rollback.ml
rollback:
	dune exec rollback_ocaml_webapp

# Update the package dependencies when new deps are added to dune-project
$(opam_file): dune-project
	-dune build @install		# Update the $(project_name).opam file
	-git add $(opam_file)		# opam uses the state of master for it updates
	-git commit $(opam_file) -m "Updating package dependencies"
	opam install . --deps-only  # Install the new dependencies
