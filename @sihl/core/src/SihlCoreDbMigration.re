module Async = SihlCoreAsync;

module Status = {
  [@decco]
  type t = {
    namespace: string,
    version: int,
    dirty: SihlCoreDbMysql.Bool.t,
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
      SihlCoreDbRepo.execute(connection, stmt);
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
        SihlCoreDbRepo.getOne(
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
      SihlCoreDbRepo.getOne(
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
    type parameters = (string, int, SihlCoreDbMysql.Bool.t);

    let query = (connection, ~status: t) => {
      SihlCoreDbRepo.execute(
        ~parameters=
          parameters_encode((status.namespace, status.version, status.dirty)),
        connection,
        stmt,
      );
    };
  };
};

type t = {
  steps: string => list((int, string)),
  namespace: string,
};

let stepsToApply = (migration, currentVersion) => {
  migration.steps(migration.namespace)
  ->Belt.List.sort(((v1, _), (v2, _)) => v1 > v2 ? 1 : (-1))
  ->Belt.List.keep(((v, _)) => v > currentVersion);
};

let maxVersion = steps => {
  steps
  ->Belt.List.sort(((v1, _), (v2, _)) => v1 < v2 ? 1 : (-1))
  ->Belt.List.map(((v, _)) => v)
  ->Belt.List.head
  ->Belt.Option.getWithDefault(0);
};

let applyMigration = (migration: t, db) => {
  let namespace = migration.namespace;
  SihlCoreLog.info({j|Checking migrations for app $(namespace)|j}, ());
  SihlCoreDbDatabase.withConnection(
    db,
    conn => {
      let%Async _ = Status.CreateTableIfDoesNotExist.query(conn);
      let%Async hasStatus =
        Status.Has.query(conn, ~namespace=migration.namespace);
      let%Async _ =
        !hasStatus
          ? Status.Upsert.query(
              conn,
              ~status=Status.make(~namespace=migration.namespace),
            )
          : Async.async();
      let%Async status =
        Status.Get.query(conn, ~namespace=migration.namespace);
      let status = Belt.Result.getExn(status);
      let currentVersion = status.version;
      let steps = stepsToApply(migration, currentVersion);
      let newVersion = maxVersion(steps);
      let nrSteps = steps |> Belt.List.length;
      if (nrSteps > 0) {
        SihlCoreLog.info(
          {j|There are $(nrSteps) unapplied migrations for app $(namespace), current version is $(currentVersion) but should be $(newVersion)|j},
          (),
        );
        let%Async _ =
          steps
          ->Belt.List.map(((_, stmt), ()) =>
              SihlCoreDbRepo.execute(conn, stmt)
            )
          ->Async.allInOrder;
        Status.Upsert.query(conn, ~status={...status, version: newVersion})
        ->Async.mapAsync(_ =>
            SihlCoreLog.info(
              {j|Applied migrations for $(namespace) to reach schema version $(newVersion)|j},
              (),
            )
          );
      } else {
        SihlCoreLog.info("No migrations to apply", ());
        Async.async();
      };
    },
  );
};

let applyMigrations = (migrations: list(t), db) => {
  migrations
  ->Belt.List.map((migration, ()) => applyMigration(migration, db))
  ->Async.allInOrder;
};
