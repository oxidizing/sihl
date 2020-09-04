(* Essential services *)
module Log = Sihl.Log.Service.Make ()

module Config = Sihl.Config.Service.Make (Log)
module Db = Sihl.Data.Db.Service.Make (Config) (Log)

module Repo = Sihl.Data.Repo.Service.Make ()

module MigrationRepo = Sihl.Data.Migration.Service.Repo.MakeMariaDb (Db)

module Cmd = Sihl.Cmd.Service.Make ()

module Migration =
  Sihl.Data.Migration.Service.Make (Log) (Cmd) (Db) (MigrationRepo)

module Random = Sihl.Utils.Random.Service.Make ()

(* Repositories *)
module TokenRepo = Sihl.Token.Service.Repo.MakeMariaDb (Db) (Repo) (Migration)
module SessionRepo =
  Sihl.Session.Service.Repo.MakeMariaDb (Db) (Repo) (Migration)
module UserRepo = Sihl.User.Service.Repo.MakeMariaDb (Db) (Repo) (Migration)
module StorageRepo =
  Sihl.Storage.Service.Repo.MakeMariaDb (Db) (Repo) (Migration)
module EmailTemplateRepo =
  Sihl.Email.Service.Template.Repo.MakeMariaDb (Db) (Repo) (Migration)
module QueueRepo = Sihl.Queue.Service.Repo.MakeMariaDb (Db) (Repo) (Migration)

(* Services *)
module Token = Sihl.Token.Service.Make (Log) (Random) (TokenRepo)
module Session = Sihl.Session.Service.Make (Log) (Random) (SessionRepo)
module User = Sihl.User.Service.Make (Log) (Cmd) (Db) (UserRepo)
module Storage = Sihl.Storage.Service.Make (Log) (StorageRepo) (Db)
module EmailTemplate =
  Sihl.Email.Service.Template.Make (Log) (EmailTemplateRepo)
module PasswordReset = Sihl.User.PasswordReset.Service.Make (Log) (Token) (User)
module Schedule = Sihl.Schedule.Service.Make (Log)
module Queue = Sihl.Queue.Service.MakePolling (Log) (Schedule) (QueueRepo)
