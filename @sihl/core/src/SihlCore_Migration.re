module Async = SihlCore_Async;
module Db = SihlCore_Db;
module Log = SihlCore_Log;

let applyMigration =
    (module I: Db.DATABASE_INSTANCE, migration: Db.Migration.t) => {
  let namespace = migration.namespace;
  Log.info({j|Checking migrations for app $(namespace)|j}, ());
  I.Database.withConnection(
    I.database,
    conn => {
      module C = (val conn: Db.CONNECTION_INSTANCE);
      let conn = C.connection;
      let%Async _ = C.Connection.Migration.setup(conn);
      let%Async hasStatus =
        C.Connection.Migration.has(conn, ~namespace=migration.namespace);
      let%Async _ =
        !hasStatus
          ? C.Connection.Migration.upsert(
              conn,
              ~status=
                C.Connection.Migration.Status.make(
                  ~namespace=migration.namespace,
                ),
            )
            ->Async.mapAsync(_ => ())
          : Async.async();
      let%Async status =
        C.Connection.Migration.get(conn, ~namespace=migration.namespace);
      let status = Belt.Result.getExn(status);
      let currentVersion = C.Connection.Migration.Status.version(status);
      let steps = Db.Migration.stepsToApply(migration, currentVersion);
      let newVersion = Db.Migration.maxVersion(steps);
      let nrSteps = steps |> Belt.List.length;
      if (nrSteps > 0) {
        Log.info(
          {j|There are $(nrSteps) unapplied migrations for app $(namespace), current version is $(currentVersion) but should be $(newVersion)|j},
          (),
        );
        let%Async _ =
          steps
          ->Belt.List.map(((_, stmt), ()) => {
              C.Connection.execute(conn, ~stmt, ~parameters=None)
              ->Async.mapAsync(_ => ())
            })
          ->Async.allInOrder;
        C.Connection.Migration.upsert(
          conn,
          ~status=
            C.Connection.Migration.Status.setVersion(status, ~newVersion),
        )
        ->Async.mapAsync(_ =>
            Log.info(
              {j|Applied migrations for $(namespace) to reach schema version $(newVersion)|j},
              (),
            )
          );
      } else {
        Log.info("No migrations to apply", ());
        Async.async();
      };
    },
  );
};

let applyMigrations =
    (module I: Db.DATABASE_INSTANCE, migrations: list(Db.Migration.t)) => {
  migrations
  ->Belt.List.map((migration, ()) => applyMigration((module I), migration))
  ->Async.allInOrder;
};
