build:
	@dune build @install

clean:
	@dune clean

# coverage: clean
#	@BISECT_ENABLE=YES dune runtest --force
#	@bisect-ppx-report -I _build/default/ -html _coverage/ \
#	  `find . -name 'bisect*.out'`

test:
	@dune runtest --force
