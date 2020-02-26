# Design goals

## Developer happiness

This design goal is inspired by Ruby and Ruby on Rails.

### Practices

* don't break expectations
* provide versioned documentation
* provide examples, recipes and tutorial to tackle common problems
* don't just generate documentation out of function signatures
* favor pragmatic and sane defaults over "sound" or "pure" APIs
* minimize accidental complexity so the developer can focus on the problem of the business
* minimize the amount of magic by minimizing the use usage of compiler extensions, the module system and opening modules globally
* favor ease of reading to ease of editing, favor ease of editing to ease of writing

## Familiarity

The expectations of developers who are familiar with the basic principles of functional programming should not get broken. It should be possible for JavaScript developers coming from React and Node to get productive after one day of learning. The language syntax, tooling and concepts should feel familiar from the beginning.

### Practices

* assume a web developer with following profile: basic understanding of Functional Programming, React or similar Functional Programming frontend library, functional JavaScript on the backend
* use the ReasonML syntax instead of the OCaml syntax because it was designed to be close to JavaScript
* make sure basic APIs are just namespaced functions encouraging function composition as main tool for abstraction

## Rapid development without sacrificing maintanability

It should be possible to develop applications reasonably fast without taking up a lot of technical debt. Development productivity should be kept up in the long run.

### Practices

* turn runtime errors into compile time errors
* use compiler inference to write experiments without type annotations
* use compiler to generate module interfaces when API has settled
* use end to end type safety, from click on button in React app all the way to the Postgres driver
* encourage declarative programming by designing APIs in a clever way

## Guided Composability

Instead of being stuck on rails, it should be possible to build things by composing smaller things. There should be guidance for that process.

### Practices

* provide discoverable APIs by using ReasonML modules as namespaces
* provide sane defaults in APIs by making strong assumptions about the usage
* provide a CLI to scaffold apps to demonstrating how the compose can be composed
* favor function composition over DSLs using ADTs in APIs
* guide the developer towards separation of the *what* from the *how*
* guide the developer to write small pure functions that are easy to test
