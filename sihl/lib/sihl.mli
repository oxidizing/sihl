(**
{0 Sihl}

Sihl is a framework for building applications with Reason and OCaml.

{1 Overview}

{e Streaming} uses composable stream producers (sources), consumers (sinks) and
transformers (flows). The central model that abstracts over them is a
{{!module:Streaming.Stream} [Stream]}.

The following features are provided:

- {b Constant memory usage}: large or infinite streams can be computed in constant
  and small space. Buffering of the input is possible when needed.
- {b Excellent performance}: all models were designed with performance at the
  core. See {{:https://github.com/rizo/streams-bench} benchmarks} for detailed
  comparison with other libraries.
- {b Resource safety}: resources in effectful streaming pipelines are allocated
  lazily and released as early as possible. Resources are guaranteed to
  be terminated even when streams rise exceptions.
- {b Flexibility and loose coupling}: push-based and pull-based models are
  implemented to allow efficient zipping, concatenation and implementation of
  decoupled sources, sinks and flows.
- {b Streaming notation}: build streams and sinks using a convenient
  comprehension and applicative notations (see examples {{:#using-stream-notation} below}).
 *)

(** Libraries *)
module Core = Core

module Ql = Core.Ql
module Hashing = Core.Hashing
module Jwt = Core.Jwt
module Sig = Sig
module Id = Core.Id
module Container = Core_container
module Db = Core_db
module Fail = Core_fail
module Ctx = Core_ctx
module Service = Core_service
module Http = Http
module Middleware = Middleware
module Repo = Repo
module Migration = Migration
module Run = Run

(** Extensions *)
module Admin = Admin

module Template = Template
module Authn = Authn
module Authz = Authz
module User = User
module Email = Email
module Session = Session
module Test = Test
module Storage = Storage
