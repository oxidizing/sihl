(** A Sihl app is something that can be started and stopped and that users can interact with through HTTP or CLI commands. It contains configuration, HTTP endpoints, a list of services, schedules and CLI commands. *)

(** {1 Kernel services}

  An app requires a minimal set of services. That set is called {{!Sihl.App.Sig.KERNEL} kernel services}. Kernel service implementations are provided by Sihl, so you don't need any external dependencies to get started with Sihl apps.

 *)

(** {1 App creation}

After implementing domain services which makes an app that solves a particular problem, you want to expose it to users by creating a Sihl app.

Once you have set up the kernel services, use the functor {!Sihl.App.Make} to instantiate an app like follows:

{[
module KernelServices = struct
  module Random = Sihl.Utils.Random.Service.Make ()
  module Log = Sihl.Log.Service.Make ()
  module Config = Sihl.Config.Service.Make ()
  module Db = Sihl.Data.Db.Service.Make ()
  module MigrationRepo = Sihl.Data.Migration.Service.Repo.MakeMariaDb (Db)
  module Cmd = Sihl.Cmd.Service.Make ()
  module Migration = Sihl.Data.Migration.Service.Make (Log) (Cmd) (Db) (MigrationRepo)
  module WebServer = Sihl.Web.Server.Service.Make (Log) (Cmd)
  module Schedule = Sihl.Schedule.Service.Make (Log)
end

module App = Sihl.App.Make (KernelServices)
]}
*)

module Make : functor (Kernel : App_sig.KERNEL) -> App_sig.APP

(** {1 Usage}

An {{!Sihl.App.Sig.APP}app} can be set up using a clean builder pattern. Make sure to call [run] in the end:

{[
let services = ...
let endpoints = ...
let config = ...
let schedules = ...
let commands = ...

let () =
  App.(
    empty
    |> with_services services
    |> with_endpoints endpoints
    |> with_config config
    |> with_schedules schedules
    |> with_commands commands
    |> run)
]}
 *)

module Sig = App_sig
