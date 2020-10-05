(* Essential services *)
module Database = Sihl.Data.Db.Service.Default
module Repo = Sihl.Data.Repo.Service.Default
module MigrationRepo = Sihl.Data.Migration.Service.Repo.MakeMariaDb (Database)
module Migration = Sihl.Data.Migration.Service.Make (MigrationRepo)
module Random = Sihl.Utils.Random.Service.Default

(* Repositories *)
module TokenRepo = Sihl.Token.Service.Repo.MakeMariaDb (Database) (Repo) (Migration)
module SessionRepo = Sihl.Session.Service.Repo.MakeMariaDb (Database) (Repo) (Migration)
module UserRepo = Sihl.User.Service.Repo.MakeMariaDb (Database) (Repo) (Migration)
module StorageRepo = Sihl_storage.Repo.MakeMariaDb (Database) (Repo) (Migration)

module EmailTemplateRepo =
  Sihl.Email.Service.Template.Repo.MakeMariaDb (Database) (Repo) (Migration)

module QueueRepo = Sihl.Queue.Service.Repo.MakeMariaDb (Database) (Repo) (Migration)

(* Services *)
module Token = Sihl.Token.Service.Make (Random) (TokenRepo)
module Session = Sihl.Session.Service.Make (Random) (SessionRepo)
module User = Sihl.User.Service.Make (UserRepo)
module Storage = Sihl_storage.Make (StorageRepo)
module EmailTemplate = Sihl.Email.Service.Template.Make (EmailTemplateRepo)
module PasswordReset = Sihl.User.PasswordReset.Service.Make (Token) (User)
module Schedule = Sihl.Schedule.Service.Default
module Queue = Sihl.Queue.Service.MakePolling (Schedule) (QueueRepo)
