(** A seed is a sequence of service calls that set a system state. Seeds are typically used before integration testing to set the initial state. *)

(** {1 Introduction}

A seed is a function that takes a {!Core.Ctx.t} and returns [unit Lwt.t]. It has also a name that identifies it uniquely. This means, that no two seeds are allowed to have the same name.

Seeds can be used to set some system state. This can be useful for integration tests or to add data to a live system in a controlled way.

Many other seeding systems allow for export and import of pure data. Sihl's seeding system is just a function that does several service calls. One major advantage is, that there is no seed data that needs to be migrated and the seeding is statically typed.
A disadvantage of this approach is, that seed data generation requires a Sihl app with services. *)

type t = Seed_core.t

(** {1 Installation}

{[
module Log = Sihl.Log.Service.Make ()
module Cmd = Sihl.Cmd.Service.Make ()
module Seed = Sihl.Seed.Service.Make (Log) (Cmd)
]}

*)

module Service = Service

(** {1 Usage}

{!Sihl.Seed.Service.Sig.SERVICE}

*)
