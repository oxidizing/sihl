module Bool = SihlCoreDbCore.Bool;
module Persistence = SihlCoreDbCore.Make(SihlCoreDbMysql.Mysql);

module Database = SihlCoreDbDatabase.Make(Persistence);
module Connection = SihlCoreDbCore.Connection;
module Migration = SihlCoreDbMigration.Make(Persistence);

module Repo = SihlCoreDbRepo;
