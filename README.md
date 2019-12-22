# Sihl

Sihl is a set of tools for building web applications in ReasonML. This repository contains components packaged as NPM packages, design and architecture documents and example applications.

## Goal

The goal is a workflow and a set of tools to build safe web applications quickly with long-term maintainability in mind in ReasonML.

## Concepts

### Component

A component is a library with a strong focus solving one particular problem. It is packaged as NPM packaged and it can be consumed from anyone in the NPM ecosystem. *Examples: HTTP routing, BCrypt encryption/decryption, JWT encoding/decoding*.

### App

An app is a set of

* HTTP routes
* migrations
* repositories
* business logic
* ReasonReact components

that solves one particular business problem. An app might use several components as well as other apps. Apps will be loaded by Sihl. *Examples: User management, Health monitoring, Email management*.

### Project

A project comprises of multiple apps. Sihl glues them together by merging and mounting their HTTP routes, applying their migrations in the correct order and managing their lifecycles.

### Sihl CLI

Sihl comes with a CLI for quick type, (de)serialization and repository generation.

## Components

### HTTP

The HTTP component is described by two types:
```reasonml
type Handler.t = Request.t -> Future.t(Response.t)
```
```reasonml
type Middleware.t = Handler.t -> Handler.t
```

The HTTP routes are HTTP server agnostic, we provide adapters for ExpressJS.

### Security

The security component comprises of JS bindings to JWT, BCrypt and Base64 libraries.

### Scheduler

This is a simple scheduler that makes use of the NodeJS event loop.

### Logging

The logger is non-blocking and supports multiple levels and multiple logging targets.

### Query Language

The query language is a subset of Postgrest's http://postgrest.org/en/v5.2/api.html query language. We provide adapters for various SQL backends. It has to run in the browser as well as on the server.

### Migration

The migration component is used to discover migrations and to apply them in the correct order. This component is a set of high level FS and DB tools. We provide adapters for SQL databases.

### Seeding

The seeding component can clean up existing tables and read in data from the filesystem to get the project into a certain state.

### Serialization & Deserialization

We use decco: https://github.com/reasonml-labs/decco

## Infrastructure Apps

### Emails

* send custom emails
* send bulk emails
* monitor emails sending
* expose controls through the admin UI

### Health

* monitor the performance of the HTTP routes of all the other apps
* monitor the health of all other apps
* notify through customized notification channels
* display metrics through the admin UI

### Users

* register, login, create, edit, active, deactivate users
* recover passwords
* expose user management through admin UI

### Authorization

* keep track of assigned roles and permissions
* answer: is `subject` allowed to `predicated` on `object`?
