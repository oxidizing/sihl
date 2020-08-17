(* Essential services *)
module Db = Sihl.Data.Db.Service
module Log = Sihl.Log.Service
module Config = Sihl.Config.Service
module Repo = Sihl.Data.Repo.Service
module MigrationRepo = Sihl.Data.Migration.Service.Repo.PostgreSql
module Cmd = Sihl.Cmd.Service
module Migration = Sihl.Data.Migration.Service.Make (Cmd) (Db) (MigrationRepo)

(* Repositories *)
module SessionRepo =
  Sihl.Session.Service.Repo.MakePostgreSql (Db) (Repo) (Migration)
module UserRepo = Sihl.User.Service.Repo.MakePostgreSql (Db) (Repo) (Migration)
module EmailTemplateRepo =
  Sihl.Email.Service.Template.Repo.MakePostgreSql (Db) (Repo) (Migration)

(* Services *)
module Session = Sihl.Session.Service.Make (SessionRepo)
module User = Sihl.User.Service.Make (Cmd) (Db) (UserRepo)
module EmailTemplate = Sihl.Email.Service.Template.Make (EmailTemplateRepo)
module Schedule = Sihl.Schedule.Service.Make (Log)
