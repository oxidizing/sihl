(* Essential services *)
module Database = Sihl.Database.Service.Default
module Repository = Sihl.Repository.Service.Default
module MigrationRepo = Sihl.Migration.Service.Repo.MakePostgreSql (Database)
module Random = Sihl.Utils.Random.Service.Default
module Migration = Sihl.Migration.Service.Make (MigrationRepo)

(* Repositories *)
module SessionRepo =
  Sihl.Session.Service.Repo.MakePostgreSql (Database) (Repository) (Migration)

module UserRepo = Sihl.User.Repo.MakePostgreSql (Database) (Repository) (Migration)

module EmailTemplateRepo =
  Sihl_email.Template.Repo.MakePostgreSql (Database) (Repository) (Migration)

(* Services *)
module Session = Sihl.Session.Service.Make (Random) (SessionRepo)
module User = Sihl.User.Service.Make (UserRepo)
module EmailTemplate = Sihl_email.Template.Make (EmailTemplateRepo)
module Schedule = Sihl.Schedule.Service.Default
