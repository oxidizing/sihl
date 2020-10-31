(** Sihl is a high-level web application framework providing a set of composable building
    blocks and recipes that allow you to develop web apps quickly and sustainably.
    Statically typed functional programming with OCaml makes web development fun and safe.

    Things like database migrations, HTTP routing, user management, sessions, logging,
    emailing, job queues and schedules are just a few of the topics Sihl takes care of.

    Let's have a look at a tiny Sihl app in a file called [sihl.ml]:

    {[
      module Service = struct
        module WebServer = Sihl.Web.Server.Service.Opium
      end

      let hello_page =
        Sihl.Web.Route.get "/hello/" (fun _ ->
            Sihl.Web.Res.(html |> set_body "Hello!") |> Lwt.return)
      ;;

      let endpoints = [ "/page", [ hello_page ], [] ]
      let services = [ Service.WebServer.configure endpoints [ "PORT", "8080" ] ]
      let () = Sihl.Core.App.(empty |> with_services services |> run)
    ]} *)

(** {1 Authentication}*)

module Authn = Authn

(** {1 Authorization} *)

module Authz = Authz

(** {1 Core} *)

module Core = Core

(** {1 Database} *)

module Database = Database

(** {1 Repository} *)

module Repository = Repository

(** {1 Migration} *)

module Migration = Migration

(** {1 Emailing}*)

module Email = Email

(** {1 Message}*)

module Message = Message

(** {1 Job Queue}*)

module Queue = Queue

(** {1 Random} *)

module Random = Random

(** {1 Scheduler} *)

module Schedule = Schedule

(** {1 Session}*)

module Session = Session

(** {1 Storage}*)

module Storage = Storage

(** {1 Token}*)

module Token = Token

(** {1 User Management}*)

module User = User
module Password_reset = Password_reset

(** {1 Utils & Helpers} *)

module Utils = Utils

(** {1 Http} *)

module Http = Http
module Middleware = Middleware
