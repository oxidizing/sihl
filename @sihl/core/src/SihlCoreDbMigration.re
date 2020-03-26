module Async = SihlCoreAsync;

module Make = (Persistence: SihlCoreDbCore.PERSISTENCE) => {
  module Database = SihlCoreDbDatabase.Make(Persistence);

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
    Database.withConnection(
      db,
      conn => {
        let%Async _ = Persistence.Migration.setupMigrationStorage(conn);
        let%Async hasStatus =
          Persistence.Migration.hasMigrationStatus(
            conn,
            ~namespace=migration.namespace,
          );
        let%Async _ =
          !hasStatus
            ? Persistence.Migration.upsertMigrationStatus(
                conn,
                ~status=
                  Persistence.Migration.Status.make(
                    ~namespace=migration.namespace,
                  ),
              )
            : Async.async();
        let%Async status =
          Persistence.Migration.getMigrationStatus(
            conn,
            ~namespace=migration.namespace,
          );
        let status = Belt.Result.getExn(status);
        let currentVersion = Persistence.Migration.Status.version(status);
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
                Persistence.Connection.execute(conn, ~stmt, ~parameters=None)
                ->Async.mapAsync(_ => ())
              )
            ->Async.allInOrder;
          Persistence.Migration.upsertMigrationStatus(
            conn,
            ~status=
              Persistence.Migration.Status.setVersion(status, ~newVersion),
          )
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
};
