(* Core *)
module Container = Sihl_core.Container
module App = Sihl_core.App
module Configuration = Sihl_core.Configuration
module Command = Sihl_core.Command
module Log = Sihl_core.Log
module Random = Sihl_core.Random

(* Contract *)
module Contract = Sihl_contract

(* Services *)
module Service = struct
  module Authn = Sihl_user.Authn
  module Database = Sihl_persistence.Database
  module Email = Sihl_email
  module Email_template = Sihl_email.Template
  module Email_template_repo = Sihl_email.Template_repo
  module Http = Sihl_web.Http
  module Migration = Sihl_persistence.Migration
  module Migration_repo = Sihl_persistence.Migration_repo
  module Password_reset = Sihl_user.Password_reset
  module Repository = Sihl_persistence.Repository
  module Schedule = Sihl_core.Schedule
  module Session = Sihl_user.Session
  module Session_repo = Sihl_user.Session_repo
  module Storage = Sihl_storage
  module Token = Sihl_user.Token
  module Token_repo = Sihl_user.Token_repo
  module User = Sihl_user.User
  module User_repo = Sihl_user.User_repo
  module Queue = Sihl_queue
end

(* Types *)
module Database = Sihl_contract.Database
module Email = Sihl_contract.Email
module Email_template = Sihl_contract.Email_template

module Http = struct
  module Route = Sihl_contract.Http
end

module Migration = Sihl_contract.Migration

module Queue = struct
  module Job = Sihl_contract.Queue_job
  module Job_instance = Sihl_contract.Queue_job_instance
  module Workable_job = Sihl_contract.Queue_workable_job
end

module Session = Sihl_contract.Session
module Authz = Sihl_user.Authz

module Storage = struct
  module File = Sihl_contract.Storage.File
  module Stored = Sihl_contract.Storage.Stored
end

module Token = Sihl_contract.Token
module User = Sihl_contract.User
module Utils = Sihl_core.Utils
module Time = Sihl_core.Time

(* Rest *)
module Middleware = Sihl_web.Middleware
