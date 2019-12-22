# Sihl

Sihl is a set of tools for building web applications in ReasonML. This repository contains components packaged as NPM packages, design and architecture documents and example applications.

## Goal

The goal is a workflow and a set of tools to build safe web applications quickly with long-term maintainability in mind in ReasonML.

## Concepts

### Component

A component is a library with a strong focus solving one particular problem. It is packaged as NPM packaged and it can be consumed from anyone in the NPM ecosystem. *Examples: HTTP routing, BCrypt encryption/decryption, JWT encoding/decoding*.

### App

An app is a set of HTTP routes, migrations, repositories and business logic that solve one particular business problem. An app might use several components as well as other apps. Apps will be loaded by Sihl. *Examples: User management, Health monitoring, Email management*.

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

### Authorization & Permissions

### Scheduler

### Logging

### Query Language

### Migrations & Seeding

### Serialization & Deserialization

We use decco: https://github.com/reasonml-labs/decco

## Infrastructure Apps

### Emails

### Health

### Users
