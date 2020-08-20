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
    A web framework for functional web development in OCaml and Reason.
    <br />
    <a href="https://oxidizing.github.io/sihl/"><strong>Explore the docs »</strong></a>
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
* [Usage](#usage)
  * [Configuration](#configuration)
  * [Web](#web)
  * [Database](#database)
  * [CLI](#cli)
  * [Logging](#logging)
  * [User](#user)
  * [Authentication](#authentication)
  * [Authorization](#authorization)
  * [Message](#message)
  * [Token](#token)
  * [Session](#session)
  * [Schedule](#schedule)
  * [Email](#email)
  * [Job queue](#job-queue)
  * [Storage](#storage)
  * [Testing](#testing)
* [Roadmap](#roadmap)
* [Contributing](#contributing)
* [License](#license)
* [Contact](#contact)
* [Acknowledgements](#acknowledgements)

## About 

You want to skip the "blah blah" and go straight to the code? [Get started here.](#getting-started)

### What Sihl is not

Let's start by clarifying what Sihl is not:

#### No MVC framework

Sihl will not help you generate models, controllers and views quickly. 
It doesn't use convention over configuration and instead tries to be as explicit as necessary. We think the speedup of generating MVC and auto-wiring pales in comparison to the long-term maintanability concerns

#### No microservice framework

Sihl encourages you to build things in a service-oriented way, but it's not a microservice framework that deals with problems of distributed systems. Use your favorite FaaS/PaaS/container orchestrator/micro-service toolkit to deal with that and Sihl for the business logic.

### What Sihl is

Now that we have that out of the way, let's have a look what Sihl *is*.

Sihl is a high-level application framework that can be used for web development. It provides a set of composable building blocks and recipes that allow you to develop (web) apps quickly but sustainably. 
Statically typed functional programming with OCaml makes web development fun and safe.

Things like database migrations, HTTP routing, user management, sessions, logging, emailing, job queues and schedules are just a few of all the topics Sihl takes care of.

### Do we need another web framework?

Yes, because all other frameworks didn't grow here.

On a more serious note, originally we wanted to collect a set of services, libraries, best practices and architecture to quickly and sustainably spin-off our tools and product. 
An evaluation of languages and tools lead us to build the 5th iteration of what became Sihl with OCaml. We believe OCaml is a phenomenal host, even though its house of web development is small at the moment.

Sihl is built on OCaml because OCaml ...

* ... runs fast 
* ... compiles *really* fast 
* ... is portable and works well on Linux
* ... is strict but not pure
* ... is fun to use

But the final and most important reason is the module system, which gives Sihl its modularity and strong compile-time guarantees about a project setup.
Sihl uses OCaml modules for statically typed dependency injection. If your app compiles, the dependencies are wired up correctly. You can not use what's not there.

Learn more about it in the [concepts](#concepts).

## Getting Started

Following are the steps to quickly get started with a minimal running web server.

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
let services : (module Sihl.Core.Container.SERVICE) list =
  [ (module Service.WebServer) ]

let hello_page =
  Sihl.Web.Route.get "/hello/" (fun _ ->
      Sihl.Web.Res.(html |> set_body "Hello!") |> Lwt.return)

let hello_api =
  Sihl.Web.Route.get "/hello/" (fun _ ->
      Sihl.Web.Res.(json |> set_body {|{"msg":"Hello!"}|}) |> Lwt.return)

let routes = [ ("/page", [ hello_page ], []); ("/api", [ hello_api ], []) ]

module App = Sihl.App.Make (Service)

let _ = App.(empty |> with_services services |> with_routes routes |> run)
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

## Usage

See the [open issues](https://github.com/github_username/repo/issues) for a list of proposed features (and known issues).

### Configuration

Some services need to be configured. An email service using an SMTP transport needs to know SMTP credentials in order to send emails and a database service needs to know the `DATABASE_URL` in order to establish a connection to the database.

A configuration is a simple map where the keys and values are strings.

There are two ways to deal with configuration.

#### Service configuration provider

Most services need a configuration provider in the service setup file. Let's have a look at the SMTP email service. 

```ocaml
(* Email template service setup, is responsible for rendering emails *)
module EmailTemplateRepo =
  Sihl.Email.Service.Template.Repo.MakeMariaDb (Db) (Repo) (Migration)
module EmailTemplate = Sihl.Email.Service.Template.Make (EmailTemplateRepo)

(* The provided EnvConfigProvider reads configuratin from env variables *)
module EmailConfigProvider = Sihl.Email.Service.EnvConfigProvider

(* The email service requires a configuration provider. It uses it to 
   fetch configuration on its own. *)
module Email =
  Sihl.Email.Service.Make.Smtp(EmailTemplate, EmailConfigProvider)
```

The type of `EmailConfigProvider` is different from service implementation to service implementation. The type of the config provider for SMTP is: 


```ocaml
val sender : Core.Ctx.t -> (string, string) Lwt_result.t

val username : Core.Ctx.t -> (string, string) Lwt_result.t

val password : Core.Ctx.t -> (string, string) Lwt_result.t

val host : Core.Ctx.t -> (string, string) Lwt_result.t

val port : Core.Ctx.t -> (int option, string) Lwt_result.t

val start_tls : Core.Ctx.t -> (bool, string) Lwt_result.t

val ca_dir : Core.Ctx.t -> (string, string) Lwt_result.t
```

Note that it returns the configuration asynchronously. This is not needed when reading environment variables, but it allows you to implement your own config provider that reads configuration from elsewhere in a non-blocking way.

#### Configuration service

Use the [configuration service](https://oxidizing.github.io/sihl/sihl/Sihl__/Config_sig/module-type-SERVICE/index.html) to read configuration from various sources.

A configuration is just a record holding configuration maps for `development`, `test`, and `production`.

```ocaml
let config =
  Sihl.Config.create
    ~development:
      [ ("DATABASE_URL", "mariadb://root:password@127.0.0.1:3306/dev") ]
    ~test:[ ("DATABASE_URL", "mariadb://root:password@127.0.0.1:3306/test") ]
    ~production:[]
```

The environment variables override the configuration provided as data like above.

### Web

Use the [web server service](https://oxidizing.github.io/sihl/sihl/Sihl__/Web_server_sig/module-type-SERVICE/index.html) to register HTTP routes and to start a web server.

#### Installation

`service.ml`:

```ocaml
...
module Cmd = Sihl.Cmd.Service
module WebServer = Sihl.Web.Server.Service.Make (Cmd)
...
```

`app.ml`:

```ocaml
...
let services: (module Sihl.Core.Container.SERVICE) list =
  [
    ...
    (module Service.WebServer);
    ...
  ]
...
```

#### Route

Create routes, assign them to a path and to a list of middlewares:

```ocaml
let hello_page =
  Sihl.Web.Route.get "/hello/" (fun _ ->
      Sihl.Web.Res.(html |> set_body "Hello!") |> Lwt.return)

let hello_api =
  Sihl.Web.Route.get "/hello/" (fun _ ->
      Sihl.Web.Res.(json |> set_body {|{"msg":"Hello!"}|}) |> Lwt.return)

let routes = [ ("/page", [ hello_page ], []); ("/api", [ hello_api ], []) ]

let _ = App.(empty |> with_services services |> with_routes routes |> run)
```

#### Middleware

[TODO]

#### Template

[TODO]

### Database

Use the [database service](https://oxidizing.github.io/sihl/sihl/Sihl__/Database_sig/module-type-SERVICE/index.html) to connect to databases and to run queries.

#### Installation

The database service uses [caqti](https://github.com/paurkedal/ocaml-caqti) under the hood. Caqti can dynamically load the correct driver based on the `DATABASE_URL` (postgresql://). 

Caqti supports following databases (caqti drivers):

* PostgreSQL (caqti-driver-postgresql)
* MariaDB (caqti-driver-mariadb)
* SQLite (caqti-driver-sqlite)

`service.ml`:

```ocaml
...
module Db = Sihl.Data.Db.Service
...
```

`app.ml`:

```ocaml
let services : (module Sihl.Core.Container.SERVICE) list =
  [ (module Service.Db) ]

let _ = App.(empty |> with_services services |> run)
```

Install one of the drivers listed above.

```sh
opam install caqti-driver-postgresql
```

`dune`:
```
...
caqti-driver-postgresql
...
```

#### Usage

Register the database middleware, so other services can query the database with the context that contains the database pool.

```ocaml
module DbMiddleware = Sihl.Web.Middleware.Db.Make (Service.Db)
let middlewares = [ 
  ...
  DbMiddleware.m();
  ...
]
```

The database service should be used mostly in repositories and not in services themselves.

`pizza_order_repo.ml`:

```ocaml
module MakePostgreSql 
    (DbService: Sihl.Data.Db.Sig.SERVICE) : Pizza_order_sig.REPO =
struct

  let find_request =
    Caqti_request.find_opt Caqti_type.string Model.t
      {sql|
        SELECT
          uuid,
          customer,
          pizza,
          amount,
          status,
          confirmed,
          created_at,
          updated_at
        FROM pizza_orders 
        WHERE pizza_orders.uuid = ?::uuid
        |sql}

  let find ctx ~id =
    DbService.query ctx (fun connection ->
        let module Connection = (val connection : Caqti_lwt.CONNECTION) in
        Connection.find_opt get_request id
        |> Lwt_result.map_err Caqti_error.show)

end
```

`pizza_order_service.ml`:

```ocaml
module Make 
    (Repo: Pizza_order_sig.REPO) : Pizza_order_sig.SERVICE = struct

    let find ctx ~id = Repo.find ctx ~id
end
```

### CLI

The [command line service](https://oxidizing.github.io/sihl/sihl/Sihl__/Cmd_sig/module-type-SERVICE/index.html).
 
[TODO] 

### Logging

The [logging service](https://oxidizing.github.io/sihl/sihl/Sihl__/Log_sig/module-type-SERVICE/index.html).

[TODO] 

### User

The [user service](https://oxidizing.github.io/sihl/sihl/Sihl__/User_sig/module-type-SERVICE/index.html).

[TODO] 

### Authentication

The [authentication service](https://oxidizing.github.io/sihl/sihl/Sihl__/Authn_sig/module-type-SERVICE/index.html). 

[TODO] 

### Authorization

[Authorization](https://oxidizing.github.io/sihl/sihl/Sihl/Authz/index.html) is not implemented as a service as it provides only simple pure functions. 

### Message

The [message service](https://oxidizing.github.io/sihl/sihl/Sihl__/Message_sig/module-type-SERVICE/index.html). 

[TODO] 

### Token

The [token service](https://oxidizing.github.io/sihl/sihl/Sihl__/Token_sig/module-type-SERVICE/index.html).

[TODO] 

### Session

The [session service](https://oxidizing.github.io/sihl/sihl/Sihl__/Session_sig/module-type-SERVICE/index.html).

[TODO] 

### Schedule

The [schedule service](https://oxidizing.github.io/sihl/sihl/Sihl__/Schedule_sig/module-type-SERVICE/index.html).

[TODO] 

### Email

The [email service](https://oxidizing.github.io/sihl/sihl/Sihl__/Email_sig/module-type-SERVICE/index.html).

[TODO] 

#### Delayed Email

The [delayed email service](https://oxidizing.github.io/sihl/sihl/Sihl__/Email_sig/module-type-SERVICE/index.html) looks exactly the same as the usual email service.

[TODO] 

### Job queue

The [job queue service](https://oxidizing.github.io/sihl/sihl/Sihl__/Queue_sig/module-type-SERVICE/index.html).

[TODO] 

#### Polling job queue

The [polling job queue service](https://oxidizing.github.io/sihl/sihl/Sihl__/Queue_sig/module-type-SERVICE/index.html) looks exactly the same as the normal queue service.

[TODO] 

### Storage

The [storage service](https://oxidizing.github.io/sihl/sihl/Sihl__/Storage_sig/module-type-SERVICE/index.html).

[TODO] 

### Testing

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
[release-date]: https://img.shields.io/github/release-date/oxidizing/sihl

