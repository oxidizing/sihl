module Persistence = SihlCoreDbCore.Make(SihlCoreDbMysql.Mysql);

module Bool = SihlCoreDbCore.Bool;
module Connection = SihlCoreDbCore.Connection;

module Database = SihlCoreDbDatabase.Make(Persistence);
module Migration = SihlCoreDbMigration.Make(Persistence);
module Repo = SihlCoreDbRepo.Make(Persistence);
