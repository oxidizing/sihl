<p align="center">
  <a href="https://github.com/oxidizing/sihl">
    <img src="images/logo.png" alt="Logo">
  </a>
  <p align="center">
    A modular and functional web framework
    <br />
    <a href="https://oxidizing.github.io/sihl">
    <strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/oxidizing/sihl#getting-started">Getting Started</a>
    ·
    <a href="https://github.com/oxidizing/sihl-demo">Demo project</a>
    ·
    <a href="https://github.com/oxidizing/sihl/issues">Report Bug</a>
    ·
    <a href="https://github.com/oxidizing/sihl/issues">Request Feature</a>
  </p>
</p>

<!-- TABLE OF CONTENTS -->
## Table of Contents

* [About](#about)
* [Getting Started](#getting-started)
  * [Prerequisites](#prerequisites)
  * [Create a project](#create-a-project)
* [Background](#background)
* [Documentation](#documentation)
* [Roadmap](#roadmap)
* [Contributing](#contributing)
* [License](#license)
* [Contact](#contact)
* [Acknowledgements](#acknowledgements)

## About 

*Note that even though Sihl is being used in production, the API is still under active development.*

Sihl is a batteries-included web framework built on top of [Opium](https://github.com/rgrinberg/opium), [caqti](https://github.com/paurkedal/ocaml-caqti), [logs](https://erratique.ch/software/logs) and [many more](https://github.com/oxidizing/sihl/blob/master/dune-project). Thanks to the modular architecture, included batteries can be swapped easily. Statically typed functional programming with OCaml makes web development fun and safe.

## Getting Started

Checkout the [getting started](https://oxidizing.github.io/sihl/sihl/index.html#getting-started) section of the documentation.

If you want to jump into code have a look at the [demo project](https://github.com/oxidizing/sihl-demo). 

## Background

### Design Goals

These are the main design goals of Sihl.

#### Fun

The overarching goal is to make web development fun. *Fun* is hard to quantify, so let's just say *fun* is maximized when frustration is minimized. This is what the other design goals are here for.

#### Swappable batteries included

Sihl should provide high-level features that are common in web applications out-of-the-box. It should provide sane and ergonomic defaults for 80% of the use cases with powerful but not necessarily ergonomic customization options for the other 20%.

#### Ergonomic but safe

OCaml itself ensures a certain level of correctness at compile-time. In order to optimized developer experience, some things are not verified at compile-time but at start-time. Sihl makes sure that your app does not start without the needed configurations and the required environment.

### Features

These are some of things that Sihl can take care of for you.

- Database handling (pooling, transactions, migrations)
- Configuration (from env variables to configuration services)
- Logging
- User management
- Token management 
- Session management 
- HTTP routes & middlewares
- Flash Messages 
- Authentication
- Authorization
- Emailing
- CLI Commands
- Job Queue
- Schedules
- Block Storage

### Do we need another web framework?

Yes, because all other frameworks have not been invented here!

On a more serious note, originally we wanted to collect a set of services, libraries, best practices and architecture to quickly and sustainably spin-off our own tools and products. 
An evaluation of languages and tools lead us to build the 5th iteration of what became Sihl with OCaml. We believe OCaml is a phenomenal place to build web apps.

Thanks to OCaml Sihl is ...

* ... runs fast 
* ... compiles fast 
* ... is pragmatic and safe
* ... is fun to use

## Documentation

The API documentation for the latest version can be found here: https://oxidizing.github.io/sihl

## Roadmap

Our main goal is to stabilize the service APIs, so updating Sihl in the future becomes easier. We would like to attract contributions for service contributions, once the framework reaches some level of maturity.

## Contributing

Check out the [Contributing guidelines](/oxidizing/sihl/blob/master/docs/CONTRIBUTING.md).

## License

Copyright (c) 2020 [Oxidizing Systems](https://oxidizing.io/)

Distributed under the MIT License. See `LICENSE` for more information.

## Contact

Oxidizing Systems - [@oxidizingsys](https://twitter.com/oxidizingsys) - hello@oxidizing.io

Project Link: [https://github.com/oxidizing/sihl](https://github.com/oxidizing/sihl)
