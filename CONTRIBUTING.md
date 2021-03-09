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

1. Set version in the `dune-project` file
2. Run `opam build` to generate the `*.opam` files
3. Set the version as annotated git tag (`git tag -a 0.3.0`)
3. Push the annotated tag (`git push origin 0.3.0`)
4. Create the PR to the opam repository (`opam publish`)
5. Check out the `gh-pages` branch (`git checkout gh-pages`)
6. Generate the recent documentation (`make doc`)
7. Commit and push new documentation
