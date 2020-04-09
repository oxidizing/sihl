module Sihl = SihlMysql_Sihl;
module Async = Sihl.Core.Async;

module Persistence: SihlMysql_Sihl.Core.Db.PERSISTENCE = {
  let setup = url => {
    let%Async db = SihlMysql_Persistence.Database.setup(url);
    module DatabaseInstance: SihlCore_Db.DATABASE_INSTANCE = {
      module Database:
        SihlCore_Db.DATABASE with
          type connection = (module SihlCore_Db.CONNECTION_INSTANCE) = SihlMysql_Persistence.Database;
      let database = db;
    };
    Async.async @@ (module DatabaseInstance);
  };
};
