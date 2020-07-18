module Migration =
  Sihl.Data.Migration.Service.Make (Sihl.Data.Migration.Service.RepoPostgreSql)
module Repo = Sihl.Data.Repo.Service
module Session =
  Sihl.Session.Service.Make (Migration) (Sihl.Session.Service.Repo.PostgreSql)
    (Repo)
module User =
  Sihl.User.Service.Make (Sihl.User.Service.Repo.PostgreSql) (Migration) (Repo)
module Storage =
  Sihl.Storage.Service.Make (Migration) (Repo)
    (Sihl.Storage.Service.Repo.MariaDb)
module Test = Sihl.Test.Make (Migration)
