module Bool = SihlCoreDbCore.Bool;
module Persistence = SihlCoreDbCore.Make(SihlCoreDbMysql.Mysql);

module Database = SihlCoreDbDatabase;
module Connection = SihlCoreDbCore.Connection;

module Migration = SihlCoreDbMigration;

module Repo = SihlCoreDbRepo;
