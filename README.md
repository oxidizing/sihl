# 🌊 Sihl &middot; [![CircleCI](https://circleci.com/gh/oxidizing/sihl.svg?style=shield&circle-token=1bd6f0745de660fcdd463dbe017a67d6c8229447)](https://circleci.com/gh/oxidizing/sihl) ![GitHub](https://img.shields.io/github/license/oxidizing/sihl)

Sihl aims to be a framework like Rails or Django for Reason and OCaml. It makes web development fun and safe by turning run-time bugs into compile-time bugs.

We are working on the first public release. Documentation is in the making as well, check out this [example project](https://github.com/oxidizing/sihl-example-issues) meanwhile.

## Features

These are the things that Sihl can do for you:

* HTTP: Declarative endpoints (thanks to the abstractions of [Serbet](https://github.com/mrmurphy/serbet))
* Structure & Lifecycle: You develop Sihl apps, compose them to projects and Sihl runs them
* Migrations: Create database migrations per app, Sihl takes care of applying them
* Admin UI: Your admins will love you for the UIs you give them using the Admin UI React API
* Testing: Seed data before and clean up after your integration tests
* CLI: Create your own CLI commands per app `yarn sihl <command> <param1> <param2> ...`
* Full Stack: With [ReasonReact](https://reasonml.github.io/reason-react/) you share business logic with the backend while using React as you know it
* Async/await: Write non-blocking code without the noise of nesting Promises (or, god forbid, Callback Hell)

Check out [this blog post](https://oxidizing.io/blog/2020-03-sihl-introduction/) for more details.

## What Sihl does not do for you

* ORM: Sihl makes no assumptions about the persistence layer and it doesn't come with an ORM
* Infrastructure: You develop Sihl apps that *can* be deployed as monolith. Sihl wont help you with the deployment of apps as standalone "micro" services, please consult your trusted container/service orchestrator

## Roadmap

Currently we are focusing on the [first release](https://github.com/oxidizing/sihl/milestone/1).

Long-term goals are:
* Scaffolding: The CLI will be extended to allow generating CRUD routes, models, repositories and services quickly
* Type-safe query builder: The compiler will tell you if your SQL queries are not valid
* Native: It will be possible to access libraries form the OCaml ecosystem and compiling the backend to an executable *while sharing business logic with the frontend*

## Status of the project

The project is WIP and the APIs are not stable yet. Nevertheless we have [one project](https://oxidizing.io/#projects) in production that uses Sihl.

## License

Copyright (c) 2020 [Oxidizing Systems](https://oxidizing.io/)

Distributed under the MIT License.
