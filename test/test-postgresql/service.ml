(* Essential services *)
module Database = Sihl.Data.Db.Service.Default
module Repo = Sihl.Data.Repo.Service.Default
module MigrationRepo = Sihl.Data.Migration.Service.Repo.MakePostgreSql (Database)
module Random = Sihl.Utils.Random.Service.Default
module Migration = Sihl.Data.Migration.Service.Make (MigrationRepo)

(* Repositories *)
module SessionRepo =
  Sihl.Session.Service.Repo.MakePostgreSql (Database) (Repo) (Migration)

module UserRepo = Sihl.User.Service.Repo.MakePostgreSql (Database) (Repo) (Migration)

module EmailTemplateRepo =
  Sihl.Email.Service.Template.Repo.MakePostgreSql (Database) (Repo) (Migration)

(* Services *)
module Session = Sihl.Session.Service.Make (Random) (SessionRepo)
module User = Sihl.User.Service.Make (UserRepo)
module EmailTemplate = Sihl.Email.Service.Template.Make (EmailTemplateRepo)
module Schedule = Sihl.Schedule.Service.Default
