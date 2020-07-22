module Db = Sihl.Data.Db.Service
module Log = Sihl.Log.Service
module Migration =
  Sihl.Data.Migration.Service.Make
    (Db)
    (Sihl.Data.Migration.Service.Repo.MariaDb)
module Repo = Sihl.Data.Repo.Service.Make (Db)
module Token =
  Sihl.Token.Service.Make (Db) (Repo) (Migration)
    (Sihl.Token.Service.Repo.MariaDb)
module Session =
  Sihl.Session.Service.Make (Db) (Repo) (Migration)
    (Sihl.Session.Service.Repo.MariaDb)
module User =
  Sihl.User.Service.Make (Db) (Repo) (Migration)
    (Sihl.User.Service.Repo.MariaDb)
module Storage =
  Sihl.Storage.Service.Make (Db) (Repo) (Migration)
    (Sihl.Storage.Service.Repo.MariaDb)
module Config = Sihl.Config.Service
module Test = Sihl.Test.Make (Migration) (Config)
module EmailTemplate =
  Sihl.Email.Service.Template.Make (Db) (Repo) (Migration)
    (Sihl.Email.Service.Template.Repo.MariaDb)
module PasswordReset = Sihl.User.PasswordReset.Service.Make (Token) (User)
