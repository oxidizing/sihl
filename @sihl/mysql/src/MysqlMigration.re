module Async = Sihl.Core.Async;
module Repo = SihlCore.SihlCoreDbRepo.Make(MysqlPersistence);

module Status = {
  [@decco]
  type t = {
    namespace: string,
    version: int,
    dirty: Sihl.Core.Db.Bool.t,
  };

  let make = (~namespace) => {namespace, version: 0, dirty: false};

  module CreateTableIfDoesNotExist = {
    let stmt = "
CREATE TABLE IF NOT EXISTS core_migration_status (
  namespace VARCHAR(128) NOT NULL,
  version BIGINT,
  dirty BOOL,
  CONSTRAINT unique_namespace UNIQUE KEY (namespace)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
";

    let query = connection => {
      Repo.execute(connection, stmt);
    };
  };

  module Has = {
    let stmt = "
SELECT
  namespace,
  version,
  dirty
FROM core_migration_status
WHERE namespace = ?;
";

    [@decco]
    type parameters = string;

    let query = (connection, ~namespace) => {
      let%Async result =
        Repo.getOne(
          ~connection,
          ~stmt,
          ~parameters=parameters_encode(namespace),
          ~decode=t_decode,
          (),
        );
      result->Belt.Result.mapWithDefault(false, _ => true)->Async.async;
    };
  };

  module Get = {
    let stmt = "
SELECT
  namespace,
  version,
  dirty
FROM core_migration_status
WHERE namespace = ?;
";

    [@decco]
    type parameters = string;

    let query = (connection, ~namespace) =>
      Repo.getOne(
        ~connection,
        ~stmt,
        ~parameters=parameters_encode(namespace),
        ~decode=t_decode,
        (),
      );
  };

  module Upsert = {
    let stmt = "
INSERT INTO core_migration_status (
  namespace,
  version,
  dirty
) VALUES (
  ?,
  ?,
  ?
)
ON DUPLICATE KEY UPDATE
namespace = VALUES(namespace),
version = VALUES(version),
dirty = VALUES(dirty)
;";

    [@decco]
    type parameters = (string, int, Sihl.Core.Db.Bool.t);

    let query = (connection, ~status: t) => {
      Repo.execute(
        ~parameters=
          parameters_encode((status.namespace, status.version, status.dirty)),
        connection,
        stmt,
      );
    };
  };
};

let setupMigrationStorage = Status.CreateTableIfDoesNotExist.query;
let hasMigrationStatus = Status.Has.query;
let getMigrationStatus = Status.Get.query;
let upsertMigrationStatus = Status.Upsert.query;
