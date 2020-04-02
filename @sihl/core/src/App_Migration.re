module Async = Common_Async;

module Make = (Persistence: Common_Db.PERSISTENCE) => {
  let applyMigration = (migration: Common_Db.Migration.t, db) => {
    let namespace = migration.namespace;
    Common_Log.info({j|Checking migrations for app $(namespace)|j}, ());
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
          Common_Db.Migration.stepsToApply(migration, currentVersion);
        let newVersion = Common_Db.Migration.maxVersion(steps);
        let nrSteps = steps |> Belt.List.length;
        if (nrSteps > 0) {
          Common_Log.info(
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
              Common_Log.info(
                {j|Applied migrations for $(namespace) to reach schema version $(newVersion)|j},
                (),
              )
            );
        } else {
          Common_Log.info("No migrations to apply", ());
          Async.async();
        };
      },
    );
  };

  let applyMigrations = (migrations: list(Common_Db.Migration.t), db) => {
    migrations
    ->Belt.List.map((migration, ()) => applyMigration(migration, db))
    ->Async.allInOrder;
  };
};
