(* Libraries *)
module Core = Core
module Id = Core.Id
module Container = Core.Container
module Fail = Core.Fail
module Ctx = Core.Ctx
module Ql = Core.Ql

(* TODO move to core *)
module Sig = Sig

(* ConfigService *)
module Config = Core.Config

(* HashingService *)
module Hashing = Core.Hashing

(* RegexService *)
module Regex = Core.Regex

(* JsonService *)
module Json = Core.Json

(* RandomService *)
module Random = Core.Random

(* JwtService *)
module Jwt = Core.Jwt

(* DatabaseService *)
module Db = Core_db

(* CommandLineService *)
module Cmd = Core_cmd

(* HttpService *)
module Http = Http

(* Middlewares *)
module Middleware = Middleware

(* TemplateService *)
module Template = Template

(* RepoService *)
module Repo = Repo

(* MigrationService *)
module Migration = Migration

(* ProjectService *)
module Run = Run

(* TestService *)
module Test = Test

(* Extensions *)
module Admin = Admin
module Authn = Authn
module Authz = Authz
module Email = Email
module Session = Session
module Storage = Storage
module User = User

(*
- user.ml
- user_core.ml
- user_sig.ml
- user_service.ml
- user_authz.ml
- user_job.ml
- user_seed.ml
- user_cmd.ml
- user_web.ml
 *)
