# Contributing guidelines

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**. If you have any questions just [contact](hello@oxidizing.io) us.

## How to contribute

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/amazing-feature`)
3. Commit your Changes (`git commit -m 'Add some amazing feature'`)
4. Push to the Branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
6. Make sure all tests pass
7. Assign the Pull Request to one of the maintainers

## Release checklist

1. Update the changelog `CHANGES.md`
2. Set version in the `dune-project` file
3. Run `dune build` to generate the `*.opam` files
4. Commit and push any changes with the message `Update 0.3.0`
5. Set the version as annotated git tag (`git tag -a 0.3.0`)
6. Push the annotated tag (`git push origin 0.3.0`)
7. Create the PR to the opam repository (`opam publish`)
8. Generate and publish the documentation (`make release-doc`)
9. Create a release on Github by going to the tag list and clicking `Create release`
10. Fill in the changes of this release by copying the section of `CHANGES.md`

## Running tests

Use `make test-all` to run all tests. You can set the test databases by setting `DATABASE_URL_TEST_MARIADB` and `DATABASE_URL_TEST_POSTGRESQL`.
