<!-- PROJECT SHIELDS -->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]



<!-- PROJECT LOGO -->
<br />
<p align="center">
  <a href="https://github.com/oxidizing/sihl">
    <img src="images/logo.jpg" alt="Logo" width="400" height="240">
  </a>

  <h3 align="center">Sihl</h3>

  <p align="center">
    A framework for statically typed functional web development in OCaml and Reason.
    <br />
    <a href="https://github.com/oxidizing/sihl"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/oxidizing/sihl-example-issues">View Example Project</a>
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
    * [Folder structure](#folder-structure)
* [Usage](#usage)
  * [Configuration](#configuration)
  * [Web](#web)
    * [Route](#route)
    * [Middleware](#middleware)
  * [Database](#database)
  * [CLI](#cli)
  * [User](#user)
  * [Authorization](#authorization)
  * [Token](#token)
  * [Session](#session)
  * [Schedule](#schedule)
  * [Email](#email)
    * [Delayed Email](#delayed-email)
  * [Job queue](#job-queue)
    * [Polling job queue](#polling-job-queue_)
  * [Storage](#storage)
* [Roadmap](#roadmap)
* [Contributing](#contributing)
* [License](#license)
* [Contact](#contact)
* [Acknowledgements](#acknowledgements)

## About 

### What Sihl is not

Let's start by clarifying what Sihl is not:

* It is not an MVC framework like Rails that let's you generate models, controllers and views quickly. It doesn't use convention over configuration and instead tries to be as explicit as necessary. We think the speedup of generating MVC and auto-wiring pales in comparison to the long-term maintanability concerns.
* It is not a micro-service framework that deals with problems of distributed systems. Use your favorite FaaS/PaaS/container orchestrator/micro-service toolkit for the wiring and Sihl for the business logic.
* It is not a web framework consisting of http routing, a generic middleware mechanism and some default middlewares. While Sihl provides these things, you could use any other solution with a Sihl app to take care of the web stuff. Sihl aims to tackle a broader range of infrastructure, so you can solve domain problems.

Now that we have that out of the way, let's have a look what Sihl *is*.

### What Sihl is

Sihl is a high-level application framework that can (and is) used for web development. It provides a set of composable building blocks and recipes that allow you to develop (web) apps quickly and maintanable at the same time.
It relies heavily on OCaml, its module and static type system and on functional programming to make development fun and safe.

In order to get an idea of the responsibility Sihl claims, here is a non-exhaustive list of features:

* Database migrations, connection pooling and transaction handling
* Web (routes, middlewares, web server)
* User management
* Sessions
* Random bytes
* Tokens, JWT
* Templating
* Custom CLI commands
* Authorization
* Authentication
* Testing
* HTTP Query Language
* Logging
* Email 
* Job queue
* Scheduler
* Block Storage

### But why?

Because all other framework didn't grow here.

On a more serious note, an evaluation of languages and tools lead us to build the 5th iteration using OCaml. We believe OCaml and Reason are very nice hosts, even though their house of web development is currently small.

Some of the reasons Sihl uses OCaml:

* OCaml runs fast (not Rust fast, but maybe something like Go fast)
* OCaml compiles *really* fast (Go fast)
* OCaml is portable (and treats Linux as first class citizen)
* OCaml's type system is powerful but the language is surprisingly simple
* OCaml is strict but not pure

And the final and most important one:

* OCaml's module system allows Sihl's modularity and strong compile-time guarantees

Sihl uses OCaml modules for statically typed dependency injection. The goal is that if your app compiles, it is wired up correctly.

You can read the [concepts](#concepts) for more information.

## Getting Started

Following are the steps to quickly get started.

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

```sh
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
let services: (module Sihl.Core.Container.SERVICE) list =
  [
    (module Service.WebServer);
  ]

let hello_page =
  Sihl.Web.Route.get "/hello" (fun _ ->
      Sihl.Web.Res.(html |> set_body "Hello!") |> Lwt.return)

let hello_api =
  Sihl.Web.Route.get "/hello" (fun _ ->
      Sihl.Web.Res.(json |> set_body {|{"msg":"Hello!"}|}) |> Lwt.return)

let routes =
  [ ("page", [ hello_page ], []); ("api", [ hello_api ], []) ]

module App = Sihl.App.Make (Service)

let _ =
  App.(
    empty
    |> with_services services
    |> with_routes routes
    |> run
  )
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

and visit `http://localhost:3000/site/hello`.

## Concepts

In essence, Sihl is just a tiny core (about 100 lines) that deals with loading services and their dependencies. Every feature is built using services. 

### Services

A service is a unit that provides some functionality. Most of the time, a service is just a collection of functions that belong together. This would be the equivalent of a class with just static methods in OOP. Some services, on the other hand, can be initialized and destroyed. Sihl takes care of initializing and destroying them.

Sihl provides service interfaces and some service implementations. As an example, Sihl provides default implementation of the user service for user management with support for MariaDB and PostgreSQL. 

When you create a Sihl app, you usually start out with your service setup in a file `service.ml`. There, you list all services that you are going to use in the project. We can compose large services out of simple and small services using parameterized modules. This service composition is statically checked and you can use it throughout your project.

Sihl has to be made aware of the services you are going to use. That is why the second step of setting of services is done in the app description file.

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

## Usage

See the [open issues](https://github.com/github_username/repo/issues) for a list of proposed features (and known issues).

### Configuration
[TODO]
### Web
[TODO]
#### Route
[TODO]
#### Middleware
[TODO]
### Database
[TODO]
### CLI
[TODO]
### User
[TODO]
### Authorization
[TODO]
### Token
[TODO]
### Session
[TODO]
### Schedule
[TODO]
### Email
[TODO]
#### Delayed Email
[TODO]
### Job queue
[TODO]
#### Polling job queue
[TODO]
### Storage
[TODO]

## Roadmap

[TODO long-term plan]

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

Sihl would not be possible without amazing projects like following:

* [OCaml](https://ocaml.org/)
* [Reason](https://reasonml.github.io/)
* [Opium](https://github.com/rgrinberg/opium)
* [Caqti](https://github.com/paurkedal/ocaml-caqti)
* [Tree vector created by brgfx - www.freepik.com](https://www.freepik.com/vectors/tree)


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

