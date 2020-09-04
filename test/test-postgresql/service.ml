(* Essential services *)
module Log = Sihl.Log.Service.Make ()

module Config = Sihl.Config.Service.Make (Log)
module Db = Sihl.Data.Db.Service.Make (Config) (Log)

module Repo = Sihl.Data.Repo.Service.Make ()

module MigrationRepo = Sihl.Data.Migration.Service.Repo.MakePostgreSql (Db)

module Cmd = Sihl.Cmd.Service.Make ()

module Random = Sihl.Utils.Random.Service.Make ()

module Migration =
  Sihl.Data.Migration.Service.Make (Log) (Cmd) (Db) (MigrationRepo)

(* Repositories *)
module SessionRepo =
  Sihl.Session.Service.Repo.MakePostgreSql (Db) (Repo) (Migration)
module UserRepo = Sihl.User.Service.Repo.MakePostgreSql (Db) (Repo) (Migration)
module EmailTemplateRepo =
  Sihl.Email.Service.Template.Repo.MakePostgreSql (Db) (Repo) (Migration)

(* Services *)
module Session = Sihl.Session.Service.Make (Log) (Random) (SessionRepo)
module User = Sihl.User.Service.Make (Log) (Cmd) (Db) (UserRepo)
module EmailTemplate =
  Sihl.Email.Service.Template.Make (Log) (EmailTemplateRepo)
module Schedule = Sihl.Schedule.Service.Make (Log)
