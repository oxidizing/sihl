(* Essential services *)
module Database = Sihl.Database.Service
module Repository = Sihl.Repository.Service
module Migration = Sihl.Migration.Service.Make (Sihl.Migration.Service.Repo.MariaDb)

(* Repositories *)
module TokenRepo = Sihl.Token.Repo.MariaDb (Migration)
module SessionRepo = Sihl.Session.Service.Repo.MakeMariaDb (Migration)
module UserRepo = Sihl.User.Repo.MakeMariaDb (Migration)
module StorageRepo = Sihl_storage.Repo.MakeMariaDb (Migration)
module EmailTemplateRepo = Sihl_email.Template.Repo.MakeMariaDb (Migration)
module QueueRepo = Sihl_queue.Repo.MakeMariaDb (Migration)

(* Services *)
module Token = Sihl.Token.Service.Make (TokenRepo)
module Session = Sihl.Session.Service.Make (SessionRepo)
module User = Sihl.User.Service.Make (UserRepo)
module Storage = Sihl_storage.Make (StorageRepo)
module EmailTemplate = Sihl_email.Template.Make (EmailTemplateRepo)
module PasswordReset = Sihl.Password_reset.Service.Make (Token) (User)
module Schedule = Sihl.Schedule.Service
module Queue = Sihl_queue.MakePolling (Schedule) (QueueRepo)
