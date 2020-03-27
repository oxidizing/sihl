module Async = SihlCoreAsync;

module Make = (Persistence: SihlCoreDbCore.PERSISTENCE) => {
  let applyMigration = (migration: SihlCoreDbCore.Migration.t, db) => {
    let namespace = migration.namespace;
    SihlCoreLog.info({j|Checking migrations for app $(namespace)|j}, ());
    Persistence.Database.withConnection(
      db,
      conn => {
        let%Async _ = Persistence.Migration.setup(conn);
        let%Async hasStatus =
          Persistence.Migration.has(conn, ~namespace=migration.namespace);
        let%Async _ =
          !hasStatus
            ? Persistence.Migration.upsert(
                conn,
                ~status=
                  Persistence.Migration.Status.make(
                    ~namespace=migration.namespace,
                  ),
              )
              ->Async.mapAsync(_ => ())
            : Async.async();
        let%Async status =
          Persistence.Migration.get(conn, ~namespace=migration.namespace);
        let status = Belt.Result.getExn(status);
        let currentVersion = Persistence.Migration.Status.version(status);
        let steps =
          SihlCoreDbCore.Migration.stepsToApply(migration, currentVersion);
        let newVersion = SihlCoreDbCore.Migration.maxVersion(steps);
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
          Persistence.Migration.upsert(
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

  let applyMigrations = (migrations: list(SihlCoreDbCore.Migration.t), db) => {
    migrations
    ->Belt.List.map((migration, ()) => applyMigration(migration, db))
    ->Async.allInOrder;
  };
};
