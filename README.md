<p align="center">
  <a href="https://github.com/oxidizing/sihl">
    <img src="images/logo.png" alt="Logo">
  </a>
  <p align="center">
    A modular and functional web framework
    <br />
    <a href="https://oxidizing.github.io/sihl/sihl/Sihl/index.html">
    <strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/oxidizing/sihl-minimal-starter">View Starter Project</a>
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
  * [Installation](#installation)
  * [A simple Sihl app](#a-simple-sihl-app)
* [Documentation](#documentation)
* [Roadmap](#roadmap)
* [Contributing](#contributing)
* [License](#license)
* [Contact](#contact)
* [Acknowledgements](#acknowledgements)

## About 

*Note that even though Sihl is being used in production, the API is still under active development.*

Sihl is a high-level web application framework providing a set of composable building blocks and recipes that allow you to develop web apps quickly and sustainably. Batteries are included by they can be swapped easily.
Statically typed functional programming with OCaml makes web development fun and safe.

Let's have a look at a tiny Sihl app in a file `sihl.ml`:

```ocaml
(* Static service setup, the only service we use is the web server in this example. *)
module Service = struct
  module WebServer = Sihl.Web.Server.Service.Opium
end

let hello_page =
  Sihl.Web.Route.get "/hello/" (fun _ ->
      Sihl.Web.Res.(html |> set_body "Hello!") |> Lwt.return)

let endpoints = [ ("/page", [ hello_page ], []) ]

let services = [ Service.WebServer.configure endpoints [ ("PORT", "8080") ] ]

(* Creation of the actual app. *)

let () = Sihl.Core.App.(empty |> with_services services |> run)
```

This little web server including its dependencies compiles in 1.5 seconds on the laptop of the author. An incremental build takes about half a second. It produces an executable binary that is 33 MB in size. Executing `sihl.exe start` sets up a web server that serves one route `/page/hello/` on port 8080.

Even though you see no type definitions, the code is fully type checked by a type checker that makes you tear up as much as it brings you joy.

It runs fast. We didn't spend any efforts performance and want to make sure the API becomes somewhat stable first. Sihl will never be Rust-fast, but it might become Go-fast.

If you need stuff like job queues, emailing or password reset flows, just install one of many provided Sihl service. This is how Sihl takes cares of infrastructure and allows you to focus on the domain.

[Show me more code!](#getting-started)

### Design goals

These are the main design goals of Sihl.

#### Fun

The overarching goal is to make web development fun. *Fun* is hard to quantify, so let's just say *fun* is maximized when frustration is minimized. This is what the other design goals are trying to do.

#### Swappable batteries included

Sihl should provide high-level features that are common in web applications out-of-the-box. It should provide sane and ergonomic defaults for typical use cases with powerful but not necessarily ergonomic customization options.

#### Modular

Sihl should use an architecture with modules that bundle things that belong together. This allows us to use just what is needed and to play well with others. Hiding implementations behind interfaces together with statically typed dependency injection allows us to change any part.

#### Functional & safe 

Sihl should be built on a language that is immutable by default, has good support for functional programming, is statically typed with as much inference as possible and compiles fast.

### Features

These are some of things that Sihl can take care of. By default Sihl won't do any of it, you can enable feature by feature.

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

### What Sihl is not

Sihl is **not an MVC framework**.  Sihl does not help you generate models, controllers and views quickly. It doesn't make development of CRUD apps as quick as possible.
It doesn't use convention over configuration and instead tries to be as explicit as necessary. We think that long-term maintainability should not be sacrificed for initial speed up.

Sihl is **not only a web server**. HTTP, middlewares and routing are a small part of Sihl. They live in the web server service. 

Sihl is **not a micro service framework**. Sihl encourages you to build things in a service-oriented way, but it's not a microservice framework that deals with distributed systems. Use your favorite FaaS/PaaS/container orchestrator/micro-service toolkit together with Sihl if you like.

### Do we need another web framework?

Yes, because all other frameworks have not been invented here!

On a more serious note, originally we wanted to collect a set of services, libraries, best practices and architecture to quickly and sustainably spin-off our own tools and products. 
An evaluation of languages and tools lead us to build the 5th iteration of what became Sihl with OCaml. We believe OCaml is a phenomenal host, even though its house of web development is still small.

Sihl is built on OCaml because OCaml ...

* ... runs fast 
* ... compiles *really* fast 
* ... is portable and works well on Linux
* ... is strict but not pure
* ... is fun to use

But the final and most important reason is the module system, which gives Sihl its modularity and strong compile-time guarantees in the service setup.
Sihl uses OCaml modules for statically typed dependency injection. If your app compiles, the dependencies are wired up correctly. You can not use what's not there.

## Getting Started

Follow the steps to get started with a minimal running web server.

### Prerequisites

* Basic understanding of OCaml 
* Installation of [opam](https://opam.ocaml.org/doc/Install.html)

To initialize opam:
```sh
opam init
```

To install dune (the build system):
```sh
opam install dune
```

### Installation

To create the switch with the proper compiler version: 
```sh
opam switch create 4.08.1
opam switch 4.08.1
```

To install the database driver dependencies for MariaDB and PostgreSQL:
```sh
(Ubuntu)
sudo apt-get install -y libmariadbclient-dev libpq-dev

(Arch)
pacman -S mariadb-libs postgresql-libs
```

To install `inotifywait` to watch your build:
```sh
(Ubuntu)
sudo apt-get install -y inotify-tools

(Arch)
pacman -S inotify-tools
```

To install all dependencies and Sihl:
```sh
opam install .
opam install caqti-driver-mariadb caqti-driver-postgresql
opam install sihl
```

### A simple Sihl app

Let's a simple Sihl app, that is a simple web app with a HTTP route.

We are using [https://github.com/ocaml/dune](dune) to build the project. Create a `dune` file that specifies an executable depending on Sihl.

dune:

```
(executable
  (name app)
  (libraries
   sihl))
```

A Sihl app requires at least two things: Setting up Sihl services and creating the app definition.

Create the services file to statically set up the services and their dependencies that you are going to use in your project. Here we specify that we want to use Opium as web server.

service.ml:

```ocaml
module WebServer = Sihl.Web.Server.Service.Opium
```

The app configuration file glues services provided by Sihl and your code together. In this example, there is not much to glue except for the web server and two routes. 

app.ml:

```ocaml
let services : (module Sihl.Container.Service.Sig) list =
  [ (module Service.WebServer) ]

let hello_page =
  Sihl.Web.Route.get "/hello/" (fun _ ->
      Sihl.Web.Res.(html |> set_body "Hello!") |> Lwt.return)

let hello_api =
  Sihl.Web.Route.get "/hello/" (fun _ ->
      Sihl.Web.Res.(json |> set_body {|{"msg":"Hello!"}|}) |> Lwt.return)

let endpoints = [ ("/page", [ hello_page ], []); ("/api", [ hello_api ], []) ]

let services = [ Service.WebServer.configure endpoints [ ("PORT", "8080") ] ]

let () = Sihl.Core.App.(empty |> with_services services |> run)
```

You can build (and watch) this project with

```sh
dune build -w
```

Run the executable to get a list of all available commands:

```sh
./_build/default/app.exe
```

You should see a `start` CLI command. This comes from `Service.WebServer` which is the only service we registered. Run the command with 

```sh
./_build/default/app.exe start
```

and visit `http://localhost:3000/page/hello/` or `http://localhost:3000/api/hello/`.

Find a simple starter project [here](https://github.com/oxidizing/sihl-minimal-starter) similar to our small example.

## Documentation

The documentation for the latest version can be found here: https://oxidizing.github.io/sihl/sihl/Sihl/index.html

## Roadmap

Our main goal is to stabilize the service APIs, so updating Sihl in the future becomes easier. We would like to attract contributions for service contributions, once the framework reaches some level of maturity.

## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**. If you have any questions just [contact](#contact) us.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/amazing-feature`)
3. Commit your Changes (`git commit -m 'Add some amazing feature'`)
4. Push to the Branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

Copyright (c) 2020 [Oxidizing Systems](https://oxidizing.io/)

Distributed under the MIT License. See `LICENSE` for more information.

## Contact

Oxidizing Systems - [@oxidizingsys](https://twitter.com/oxidizingsys) - hello@oxidizing.io

Project Link: [https://github.com/oxidizing/sihl](https://github.com/oxidizing/sihl)

## Acknowledgements

Sihl would not be possible without some amazing projects like:

* [OCaml](https://ocaml.org/)
* [Reason](https://reasonml.github.io/)
* [Opium](https://github.com/rgrinberg/opium)
* [Caqti](https://github.com/paurkedal/ocaml-caqti)
* [Tree vector created by brgfx - www.freepik.com](https://www.freepik.com/vectors/tree)
* And [many more!](https://github.com/oxidizing/sihl/blob/master/dune-project)
