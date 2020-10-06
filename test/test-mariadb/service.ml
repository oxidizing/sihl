(* Essential services *)
module Database = Sihl.Database.Service.Default
module Repository = Sihl.Repository.Service.Default
module MigrationRepo = Sihl.Migration.Service.Repo.MakeMariaDb (Database)
module Migration = Sihl.Migration.Service.Make (MigrationRepo)
module Random = Sihl.Utils.Random.Service.Default

(* Repositories *)
module TokenRepo = Sihl.Token.Repo.MakeMariaDb (Database) (Repository) (Migration)

module SessionRepo =
  Sihl.Session.Service.Repo.MakeMariaDb (Database) (Repository) (Migration)

module UserRepo = Sihl.User.Repo.MakeMariaDb (Database) (Repository) (Migration)
module StorageRepo = Sihl_storage.Repo.MakeMariaDb (Database) (Repository) (Migration)

module EmailTemplateRepo =
  Sihl_email.Template.Repo.MakeMariaDb (Database) (Repository) (Migration)

module QueueRepo = Sihl_queue.Repo.MakeMariaDb (Database) (Repository) (Migration)

(* Services *)
module Token = Sihl.Token.Service.Make (Random) (TokenRepo)
module Session = Sihl.Session.Service.Make (Random) (SessionRepo)
module User = Sihl.User.Service.Make (UserRepo)
module Storage = Sihl_storage.Make (StorageRepo)
module EmailTemplate = Sihl_email.Template.Make (EmailTemplateRepo)
module PasswordReset = Sihl.Password_reset.Service.Make (Token) (User)
module Schedule = Sihl.Schedule.Service.Default
module Queue = Sihl_queue.MakePolling (Schedule) (QueueRepo)
