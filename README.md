[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
[![Release date][release-date]][release-date]


<br />
<p align="center">
  <a href="https://github.com/oxidizing/sihl">
    <img src="images/logo.jpg" alt="Logo" width="400" height="240">
  </a>

  <h3 align="center">Sihl</h3>

  <p align="center">
    A modular functional web framework 🌊
    <br />
    <a href="https://oxidizing.github.io/sihl/sihl/Sihl/index.html"><strong>Explore the docs »</strong></a>
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
* [Concepts](#concepts)
  * [Services](#services)
  * [App](#app)
* [Documentation](#documentation)
* [Roadmap](#roadmap)
* [Contributing](#contributing)
* [License](#license)
* [Contact](#contact)
* [Acknowledgements](#acknowledgements)

## About 

*Note that even though Sihl is being used in production, the API is still under active development.*

Let's have a look at a tiny Sihl app in a file `sihl.ml`:

```ocaml
module Service = struct
module Random = Sihl.Utils.Random.Service.Make ()
module Log = Sihl.Log.Service.Make ()
module Config = Sihl.Config.Service.Make (Log)
module Db = Sihl.Data.Db.Service.Make (Config) (Log)
module MigrationRepo = Sihl.Data.Migration.Service.Repo.MakeMariaDb (Db)
module Cmd = Sihl.Cmd.Service.Make ()
module Migration =
  Sihl.Data.Migration.Service.Make (Log) (Cmd) (Db) (MigrationRepo)
module WebServer = Sihl.Web.Server.Service.MakeOpium (Log) (Cmd)
module Schedule = Sihl.Schedule.Service.Make (Log)
module Seed = Sihl.Seed.Service.Make (Log) (Cmd)
end

let services : (module Sihl.Core.Container.SERVICE) list =
  [ (module Service.WebServer) ]

let hello_page =
  Sihl.Web.Route.get "/hello/" (fun _ ->
      Sihl.Web.Res.(html |> set_body "Hello!") |> Lwt.return)

let endpoints = [ ("/page", [ hello_page ], [])]

module App = Sihl.App.Make (Service)

let _ = App.(empty |> with_services services |> with_endpoints endpoints |> run)
```

This code including all its dependencies compiles in 1.5 seconds on the laptop of the author. An incremental build takes about half a second. It produces an executable binary that is 33 MB in size. Executing `sihl.exe start` sets up a webserver (which is a service) that handles one route `/page/hello/` and returns HTML containing "Hello!" in the body.

Even though you see no type definitions, the code is fully type checked by a type checker that makes you tear up as much as it brings you joy.

It runs fast, maybe. We didn't spend any efforts on measuring or tweaking performance yet. We want to make sure the API somewhat stabilizes first. Sihl will never be Rust-fast, but it might become about Go-fast.

If you need stuff like job queues, emailing or password reset flows, just add one of the provided service implementations or create one yourself by implementing a service interface.

[Enough text, show me more code!](#getting-started)

### Features

Following are the things that Sihl takes care of:

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

Let's start by clarifying what Sihl is not:

#### MVC framework

Sihl does not help you generate models, controllers and views quickly. It doesn't make development of CRUD apps as quick as possible.
It doesn't use convention over configuration and instead tries to be as explicit as necessary. We think the speedup of initial development pales in comparison to the long-term maintanability concerns in most cases.

#### Microservice framework

Sihl encourages you to build things in a service-oriented way, but it's not a microservice framework that deals with problems of distributed systems. Use your favorite FaaS/PaaS/container orchestrator/micro-service toolkit to deal with that.

### What Sihl is

Let's have a look what Sihl *is*.

Sihl is a high-level web application framework providing a set of composable building blocks and recipes that allow you to develop web apps quickly and sustainably. 
Statically typed functional programming with OCaml makes web development fun and safe.

Things like database migrations, HTTP routing, user management, sessions, logging, emailing, job queues and schedules are just a few of the topics Sihl takes care of.

### Do we need another web framework?

Yes, because all other frameworks have not been invented here!

On a more serious note, originally we wanted to collect a set of services, libraries, best practices and architecture to quickly and sustainably spin-off our own tools and product. 
An evaluation of languages and tools lead us to build the 5th iteration of what became Sihl with OCaml. We believe OCaml is a phenomenal host, even though its house of web development is small at the moment.

Sihl is built on OCaml because OCaml ...

* ... runs fast 
* ... compiles *really* fast 
* ... is portable and works well on Linux
* ... is strict but not pure
* ... is fun to use

But the final and most important reason is the module system, which gives Sihl its modularity and strong compile-time guarantees in the service setup.
Sihl uses OCaml modules for statically typed dependency injection. If your app compiles, the dependencies are wired up correctly. You can not use what's not there.

Learn more about it in the [concepts](#concepts).

### Design goals

#### Modularity

[TODO property inherited from OCaml]

#### Ergonomics over purity

[TODO use what works, just enough abstraction, not too alien for new devs]

#### Fun

[TODO longterm maintanability, minimize frustration with framework]

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
   sihl
  )
)
```

A Sihl app requires at least two things: A minimal set of services (also called kernel services) for the app to run and the actual app definition.

Create the services file to statically set up the services and their dependencies that you are going to use in your project.

service.ml:

```ocaml
module Random = Sihl.Utils.Random.Service
module Log = Sihl.Log.Service
module Config = Sihl.Config.Service
module Db = Sihl.Data.Db.Service
module MigrationRepo = Sihl.Data.Migration.Service.Repo.MariaDb
module Cmd = Sihl.Cmd.Service
module Migration = Sihl.Data.Migration.Service.Make (Cmd) (Db) (MigrationRepo)
module WebServer = Sihl.Web.Server.Service.Make (Cmd)
module Schedule = Sihl.Schedule.Service.Make(Log)
```

The app configuration file glues all the components together. In this example there is not much to glue except for the services we are going to use and two routes. 

We want a simple web service without any database (and thus no migrations), so let's just include `Service.WebServer`.

app.ml:

```ocaml
let services : (module Sihl.Core.Container.SERVICE) list =
  [ (module Service.WebServer) ]

let hello_page =
  Sihl.Web.Route.get "/hello/" (fun _ ->
      Sihl.Web.Res.(html |> set_body "Hello!") |> Lwt.return)

let hello_api =
  Sihl.Web.Route.get "/hello/" (fun _ ->
      Sihl.Web.Res.(json |> set_body {|{"msg":"Hello!"}|}) |> Lwt.return)

let endpoints = [ ("/page", [ hello_page ], []); ("/api", [ hello_api ], []) ]

module App = Sihl.App.Make (Service)

let _ = App.(empty |> with_services services |> with_endpoints endpoints |> run)
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

## Concepts

In essence, Sihl is just a tiny core (about 100 lines) that deals with loading services and their dependencies. Every feature is built using services. 

### Services

A service is a unit that provides some functionality. Most of the time, a service is just a namespace so functions that belong together are together. This would be the equivalent of a class with just static methods in object-oriented programming. However, some services can be started and stopped. These services have a lifecycles which is taken care of by Sihl.

Sihl provides service interfaces and some implementations. As an example, Sihl provides a default implementation of the user service for user management with support for MariaDB and PostgreSQL. 

When you create a Sihl app, you usually start out with your service setup in a file `service.ml`. There, you list all services that you are going to use in the project. We can compose large services out of simple and small services using parameterized modules. This service composition is statically checked and it can be used throughout your own project.

Sihl has to be made aware of the services you are going to use. That is why the second step of setting of services is done in the app description file.

[TODO explain lifecycles]

### App

A Sihl app is described in a `app.ml`. Here you glue services from `service.ml`, your own code and various other components together. It is the main entry point to your application.

#### Folder structure

Let's have a look at the folder structure of an example project called `pizza-shop`.

```
.
├── service
│   ├── dune 
│   ├── service.ml 
├── app
│   ├── dune 
│   ├── app.ml
├── components
│   ├── pizza-delivery
│   │   ├── model.ml
│   │   ├── service.ml
│   │   ├── repo.ml
│   ├── pizza-order-taking
│   │   ├── model.ml
│   │   ├── service.ml
│   │   ├── repo.ml
│   │   ├── cmd.ml
├── web
│   ├── routes.ml
│   ├── middlewares.ml
├── cli
│   ├── cmd.ml
```

There is a strong emphasis on the separation of business logic from everything else. In this example, the domain layer is split up into two parts `pizza-delivery` and `pizza-order-taking`. Note that all the business rules live in that layer. 

A set of services, models and repos on its own is not that useful. In order to make it useful, we need to expose it to users. A typical web app does that through HTTP and a few CLI commands, which are primary used for development.

Everything regarding HTTP, routing, GraphQL, REST, JSON, middlewares lives in `web`. `web` is allowed to use any service.

The folder `app` contains `app.ml` which describes a Sihl app. 

In the folder `service` contains the service configuration `service.ml`. This is the static setup of all services that are usable throughout the project.

## Documentation

The documentation for the latest released version can be found here: https://oxidizing.github.io/sihl/sihl/Sihl/index.html

## Roadmap

Our main goal is to stabilize the service APIs, so updating Sihl in the future becomes easier. We would like to attract contributions for service contributions, once the framework reaches some level of maturity.

## Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**. If you have any questions just [contact](#contact) us.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/amazing-feature`)
3. Commit your Changes (`git commit -m 'Add some amazing feature`)
4. Push to the Branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

Copyright (c) 2020 [Oxidizing Systems](https://oxidizing.io/)

Distributed under the MIT License. See `LICENSE` for more information.

## Contact

Oxidizing Systems - [@oxidizingsys](https://twitter.com/oxidizingsys) - hello@oxidizing.io

Project Link: [https://github.com/oxidizing/sihl](https://github.com/oxidizing/sihl)

## Acknowledgements

Sihl would not be possible without amazing projects:

* [OCaml](https://ocaml.org/)
* [Reason](https://reasonml.github.io/)
* [Opium](https://github.com/rgrinberg/opium)
* [Caqti](https://github.com/paurkedal/ocaml-caqti)
* [Tree vector created by brgfx - www.freepik.com](https://www.freepik.com/vectors/tree)
* And [many more!](https://github.com/oxidizing/sihl/blob/master/dune-project)

[contributors-shield]: https://img.shields.io/github/contributors/oxidizing/sihl.svg?style=flat-square
[contributors-url]: https://github.com/oxidizing/sihl/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/oxidizing/sihl.svg?style=flat-square
[forks-url]: https://github.com/oxidizing/sihl/network/members
[stars-shield]: https://img.shields.io/github/stars/oxidizing/sihl.svg?style=flat-square
[stars-url]: https://github.com/oxidizing/sihl/stargazers
[issues-shield]: https://img.shields.io/github/issues/oxidizing/sihl.svg?style=flat-square
[issues-url]: https://github.com/oxidizing/sihl/issues
[license-shield]: https://img.shields.io/github/license/oxidizing/sihl.svg?style=flat-square
[license-url]: https://github.com/oxidizing/sihl/blob/master/LICENSE.txt
[release-date]: https://img.shields.io/github/release-date/oxidizing/sihl

