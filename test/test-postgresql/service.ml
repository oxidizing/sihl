module Db = Sihl.Data.Db.Service
module Migration =
  Sihl.Data.Migration.Service.Make
    (Db)
    (Sihl.Data.Migration.Service.Repo.PostgreSql)
module Repo = Sihl.Data.Repo.Service.Make (Db)
module Session =
  Sihl.Session.Service.Make (Db) (Repo) (Migration)
    (Sihl.Session.Service.Repo.PostgreSql)
module User =
  Sihl.User.Service.Make (Db) (Repo) (Migration)
    (Sihl.User.Service.Repo.PostgreSql)
module Storage =
  Sihl.Storage.Service.Make (Db) (Repo) (Migration)
    (Sihl.Storage.Service.Repo.MariaDb)
module Config = Sihl.Config.Service
module Test = Sihl.Test.Make (Migration) (Config)
module EmailTemplate =
  Sihl.Email.Service.Template.Make (Db) (Repo) (Migration)
    (Sihl.Email.Service.Template.Repo.PostgreSql)
