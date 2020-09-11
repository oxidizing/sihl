(** Sihl is a high-level web application framework providing a set of composable building blocks and recipes that allow you to develop web apps quickly and sustainably.
Statically typed functional programming with OCaml makes web development fun and safe.

Things like database migrations, HTTP routing, user management, sessions, logging, emailing, job queues and schedules are just a few of the topics Sihl takes care of.

Let's have a look at a tiny Sihl app in a file called [sihl.ml]:

{[
module Service = struct
  module Random = Sihl.Utils.Random.Service
  module Log = Sihl.Log.Service
  module Config = Sihl.Config.Service
  module Db = Sihl.Data.Db.Service
  module MigrationRepo = Sihl.Data.Migration.Service.Repo.MariaDb
  module Cmd = Sihl.Cmd.Service
  module Migration = Sihl.Data.Migration.Service.Make (Cmd) (Db) (MigrationRepo)
  module WebServer = Sihl.Web.Server.Service.Make (Cmd)
  module Schedule = Sihl.Schedule.Service.Make (Log)
end

let services : (module Sihl.Core.Container.SERVICE) list =
  [ (module Service.WebServer) ]

let hello_page =
  Sihl.Web.Route.get "/hello/" (fun _ ->
      Sihl.Web.Res.(html |> set_body "Hello!") |> Lwt.return)

let routes = [ ("/page", [ hello_page ], []) ]

module App = Sihl.App.Make (Service)

let _ = App.(empty |> with_services services |> with_routes routes |> run)
]}

*)

(** {1 Sihl App}*)

module App = App

(** {1 Authentication}*)

module Authn = Authn

(** {1 Authorization} *)

module Authz = Authz

(** {1 CLI Command} *)

module Cmd = Cmd

(** {1 Configuration} *)

module Config = Configuration

(** {1 Core} *)

module Core = Core

(** {1 Data} *)

module Data = Data

(** {1 Emailing}*)

module Email = Email

(** {1 Logging} *)

module Log = Log

(** {1 Message}*)

module Message = Message

(** {1 Job Queue}*)

module Queue = Queue

(** {1 Scheduler} *)

module Schedule = Schedule

(** {1 Seed}*)

module Seed = Seed

(** {1 Session}*)

module Session = Session

(** {1 Storage}*)

module Storage = Storage

(** {1 Token }*)

module Token = Token

(** {1 User Management}*)

module User = User

(** {1 Utils & Helpers} *)

module Utils = Utils

(** {1 Web} *)

module Web = Web
