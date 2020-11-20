(* Essential services *)
module Database = Sihl.Service.Database
module Repository = Sihl.Service.Repository
module Migration = Sihl.Service.Migration.Make (Sihl.Service.Migration_repo.MariaDb)

(* Repositories *)
module TokenRepo = Sihl.Service.Token_repo.MariaDb (Migration)
module SessionRepo = Sihl.Service.Session_repo.MakeMariaDb (Migration)
module UserRepo = Sihl.Service.User_repo.MakeMariaDb (Migration)
module StorageRepo = Sihl_storage.Repo.MakeMariaDb (Migration)
module EmailTemplateRepo = Sihl_email.Template_repo.MakeMariaDb (Migration)
module QueueRepo = Sihl_queue.Repo.MakeMariaDb (Migration)

(* Services *)
module Token = Sihl.Service.Token.Make (TokenRepo)
module Session = Sihl.Service.Session.Make (SessionRepo)
module User = Sihl.Service.User.Make (UserRepo)
module Storage = Sihl_storage.Make (StorageRepo)
module EmailTemplate = Sihl_email.Template.Make (EmailTemplateRepo)
module PasswordReset = Sihl.Service.Password_reset.Make (Token) (User)
module Schedule = Sihl.Service.Schedule
module Queue = Sihl_queue.MakePolling (Schedule) (QueueRepo)
