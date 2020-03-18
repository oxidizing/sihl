[![CircleCI](https://circleci.com/gh/oxidizing/sihl.svg?style=svg&circle-token=1bd6f0745de660fcdd463dbe017a67d6c8229447)](https://circleci.com/gh/oxidizing/sihl)

# Sihl

Sihl aims to be a framework like Rails or Django for [Reason](https://reasonml.github.io/). It makes web development fun and safe by turning run-time bugs into compile-time bugs.

Documentation is in the making, check out this [example project](https://github.com/oxidizing/sihl-example-issues) meanwhile.

## Installation

Install Sihl from NPM: `yarn add @sihl/core`

You can install the users app as well to get user management out of the box: `yarn add @sihl/users`

## Why Reason?

The [official documentation](https://reasonml.github.io/docs/en/what-and-why#why-reason) explains it better than we ever could.

## What Sihl does for you

These are the things that Sihl can do for you:

* HTTP: Type-safe declarative routes
* Structure & Lifecycle: You develop Sihl apps, compose them to projects and Sihl runs them
* Migrations: Create database migrations per app, Sihl takes care of applying them
* Admin UI: Your admins will love you for the UIs you give them using the Admin UI React API
* Testing: Seed data before and clean up after your integration tests
* CLI: Create your own CLI commands per app `yarn sihl <command> <param1> <param2> ...`
* Run on Node.js: Use the libraries and tooling you already know
* Full Stack by Design: With the [ReasonReact](https://reasonml.github.io/reason-react/) bindings you can share business logic with the backend while using React as you know it
* Async/await: Write non-blocking code without the noise of nesting Promises (or, god forbid, callback hell)

## What Sihl does not do for you

* ORM: Sihl makes no assumptions about the persistence layer and it doesn't come with an ORM
* Infrastructure: You develop Sihl apps that *can* be deployed as monolith. Sihl wont help you with the deployment of apps as standalone "micro" services, please consult your trusted container/service orchestrator

## What Sihl will do for you in the future

* Scaffolding: The CLI will be extended to allow generating CRUD routes, models, repositories and services quickly
* Type-safe query builder: The compiler will tell you if your SQL queries are not valid
* Native: It will be possible to access libraries form the OCaml ecosystem and compiling the backend to an executable *while sharing business logic with the frontend*

## License

Copyright (c) 2020 [Oxidizing Systems GmbH](https://oxidizing.io/)

Distributed under the MIT License.
