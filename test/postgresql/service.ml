(* Essential services *)
module Database = Sihl.Service.Database
module Repository = Sihl.Service.Repository
module Migration = Sihl.Service.Migration.Make (Sihl.Service.Migration_repo.PostgreSql)

(* Repositories *)
module SessionRepo = Sihl.Service.Session_repo.MakePostgreSql (Migration)
module UserRepo = Sihl.Service.User_repo.MakePostgreSql (Migration)
module EmailTemplateRepo = Sihl_email.Template_repo.MakePostgreSql (Migration)

(* Services *)
module Session = Sihl.Service.Session.Make (SessionRepo)
module User = Sihl.Service.User.Make (UserRepo)
module EmailTemplate = Sihl_email.Template.Make (EmailTemplateRepo)
module Schedule = Sihl.Service.Schedule
