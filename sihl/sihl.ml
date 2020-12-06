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
  module Storage_repo = Sihl_storage.Repo
  module Token = Sihl_user.Token
  module Token_repo = Sihl_user.Token_repo
  module User = Sihl_user.User
  module User_repo = Sihl_user.User_repo
  module Queue = Sihl_queue
  module Queue_repo = Sihl_queue.Repo
end

(* Types *)
module Cleaner = Sihl_type.Cleaner
module Database = Sihl_type.Database
module Email = Sihl_type.Email
module Email_template = Sihl_type.Email_template

module Http = struct
  module Cookie = Sihl_type.Http_cookie
  module Middleware = Sihl_type.Http_middleware
  module Request = Sihl_type.Http_request
  module Response = Sihl_type.Http_response
  module Route = Sihl_type.Http_route
end

module Migration = Sihl_type.Migration

module Queue = struct
  module Job = Sihl_type.Queue_job
  module Job_instance = Sihl_type.Queue_job_instance
  module Workable_job = Sihl_type.Queue_workable_job
end

module Session = Sihl_type.Session
module Authz = Sihl_user.Authz

module Storage = struct
  module File = Sihl_type.Storage_file
  module Stored = Sihl_type.Storage_stored
end

module Token = Sihl_type.Token
module User = Sihl_type.User
module Utils = Sihl_core.Utils
module Time = Sihl_core.Time

(* Rest *)
module Middleware = Sihl_web.Middleware
