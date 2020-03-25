module Async = SihlCoreAsync;
module Base64 = SihlCoreBase64;
module Uuid = SihlCoreUuid;
module Bcrypt = SihlCoreBcrypt;

module Error = SihlCoreError;
module Log = SihlCoreLog;

module Persistence = SihlCoreDbCore.Make(SihlCoreDbMysql.Mysql);
module Db = SihlCoreDb;
module Http = SihlCoreHttp.Make(Persistence);

module Main = SihlCoreMain.Make(Persistence);

module Cli = SihlCoreCli.Make(Persistence);

module Config = SihlCoreConfig;

module Test = SihlCoreTest.Make(Persistence);
