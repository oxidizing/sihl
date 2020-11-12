(* Essential services *)
module Database = Sihl.Database.Service
module Repository = Sihl.Repository.Service
module MigrationRepo = Sihl.Migration.Service.Repo.PostgreSql
module Migration = Sihl.Migration.Service.Make (MigrationRepo)

(* Repositories *)
module SessionRepo = Sihl.Session.Service.Repo.MakePostgreSql (Migration)
module UserRepo = Sihl.User.Repo.MakePostgreSql (Migration)
module EmailTemplateRepo = Sihl_email.Template.Repo.MakePostgreSql (Migration)

(* Services *)
module Session = Sihl.Session.Service.Make (SessionRepo)
module User = Sihl.User.Service.Make (UserRepo)
module EmailTemplate = Sihl_email.Template.Make (EmailTemplateRepo)
module Schedule = Sihl.Schedule.Service
