module Sihl = SihlMysql_Sihl;
module Async = Sihl.Common.Async;
module Persistence = SihlMysql_Persistence;

type connection = Persistence.Connection.t;

module Status: Sihl.Common.Db.MIGRATIONSTATUS = {
  [@decco]
  type t = {
    namespace: string,
    version: int,
    dirty: Sihl.Common.Db.Bool.t,
  };
  let t_decode = Sihl.Common.Error.Decco.stringifyDecoder(t_decode);
  let make = (~namespace) => {namespace, version: 0, dirty: false};
  let version = status => status.version;
  let namespace = status => status.namespace;
  let dirty = status => status.dirty;
  let setVersion = (status, ~newVersion) => {...status, version: newVersion};
};

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
    Persistence.Connection.execute(connection, ~stmt, ~parameters=None);
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
      Persistence.Connection.getOne(
        connection,
        ~stmt,
        ~parameters=Some(parameters_encode(namespace)),
      );
    result
    ->Belt.Result.flatMap(Status.t_decode)
    ->Belt.Result.mapWithDefault(false, _ => true)
    ->Async.async;
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

  let query = (connection, ~namespace) => {
    let%Async result =
      Persistence.Connection.getOne(
        connection,
        ~stmt,
        ~parameters=Some(parameters_encode(namespace)),
      );
    result->Belt.Result.flatMap(Status.t_decode)->Async.async;
  };
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
  type parameters = (string, int, Sihl.Common.Db.Bool.t);

  let query = (connection, ~status: Status.t) => {
    Persistence.Connection.execute(
      connection,
      ~stmt,
      ~parameters=
        Some(
          parameters_encode((
            Status.namespace(status),
            Status.version(status),
            Status.dirty(status),
          )),
        ),
    );
  };
};

let setup = CreateTableIfDoesNotExist.query;
let has = Has.query;
let get = Get.query;
let upsert = Upsert.query;
