(* Core services *)
module Configuration = Sihl_core.Configuration
module Command = Sihl_core.Command
module Log = Sihl_core.Log
module Utils = Sihl_core.Utils
module Time = Sihl_core.Time

(* Web module *)
module Web = struct
  module Cookie = Opium.Cookie
  module Request = Opium.Request
  module Response = Opium.Response
  module Route = Sihl_contract.Http
  module Middleware = Sihl_web.Middleware
end

(* Persistence module *)
module Persistence = struct
  module Cleaner = Sihl_persistence.Repository
  module Database = Sihl_contract.Database
  module Migration = Sihl_contract.Migration
end

(* Email module *)
module Email = Sihl_contract.Email
module Email_template = Sihl_contract.Email_template

(* Queue module *)
module Queue = struct
  module Job = Sihl_contract.Queue_job
  module Job_instance = Sihl_contract.Queue_job_instance
  module Workable_job = Sihl_contract.Queue_workable_job
end

(* User & Security module *)
module Security = struct
  module User = Sihl_user.User
  module Session = Sihl_user.Session
  module Password_reset = Sihl_user.Password_reset
  module Authn = Sihl_user.Authn
  module Token = Sihl_user.Token
  module Random = Sihl_core.Random
  module Authz = Sihl_user.Authz
end

(* Storage module *)
module Storage = struct
  module File = Sihl_contract.Storage.File
  module Stored = Sihl_contract.Storage.Stored
end

(* Service contracts *)
module Contract = Sihl_contract

(* Service setup, should be used once in run.ml *)
module Setup = struct
  (* Core *)
  module Service = Sihl_core.Container
  module App = Sihl_core.App

  (* User & Security *)
  module Security = struct
    module User = Sihl_user.User
    module Session = Sihl_user.Session
    module Password_reset = Sihl_user.Password_reset
    module Authn = Sihl_user.Authn
    module Token = Sihl_user.Token
    module Random = struct end
  end

  (* Persistence *)
  module Persistence = struct
    module Database = Sihl_persistence.Database
    module Migration = Sihl_persistence.Migration
    module Clean = Sihl_persistence.Repository
  end

  (* Email *)
  module Email = Sihl_email
  module Email_template = Sihl_email.Template

  (* Http *)
  module Http = Sihl_web.Http

  (* Schedule *)
  module Schedule = Sihl_core.Schedule

  (* Storage *)
  module Storage = Sihl_storage

  (* Queue *)
  module Queue = Sihl_queue
end
