module Sihl = SihlMysql_Sihl;
module Async = Sihl.Core.Async;

let getMigration = (conn, ~namespace): Async.t(Sihl.Core.Db.migration('a)) => {
  let%Async migration =
    SihlMysql_Persistence.Connection.Migration.get(conn, ~namespace);
  let result: Sihl.Core.Db.migration('a) = {
    this: migration,
    version: SihlMysql_Persistence.Connection.Migration.Status.version,
    namespace: SihlMysql_Persistence.Connection.Migration.Status.namespace,
    dirty: SihlMysql_Persistence.Connection.Migration.Status.dirty,
    setVersion: SihlMysql_Persistence.Connection.Migration.Status.setVersion,
    t_decode: SihlMysql_Persistence.Connection.Migration.Status.t_decode,
  };
  Async.async @@ result;
};
let connect = db => {
  let%Async connection = SihlMysql_Persistence.Database.connect(db);
  Async.async @@
  Sihl.Core.Db.{
    this: connection,
    raw: SihlMysql_Persistence.Connection.raw,
    getMany: SihlMysql_Persistence.Connection.getMany,
    getOne: SihlMysql_Persistence.Connection.getOne,
    execute: SihlMysql_Persistence.Connection.execute,
    release: SihlMysql_Persistence.Connection.release,
    setupMigration: SihlMysql_Persistence.Connection.Migration.setup,
    getMigration,
    upsertMigration: SihlMysql_Persistence.Connection.Migration.upsert,
    makeMigration: SihlMysql_Persistence.Connection.Migration.make,
  };
};

let setup = url => {
  let%Async db = SihlMysql_Persistence.Database.setup(url);
  Async.async @@
  Sihl.Core.Db.{
    this: db,
    end_: SihlMysql_Persistence.Database.end_,
    connect,
    clean: SihlMysql_Persistence.Database.clean,
  };
};
