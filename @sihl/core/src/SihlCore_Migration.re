module Async = SihlCore_Async;
module Db = SihlCore_Db;
module Log = SihlCore_Log;

let applyMigration = (module I: Db.PERSISTENCE, migration: Db.Migration.t, db) => {
  let namespace = migration.namespace;
  Log.info({j|Checking migrations for app $(namespace)|j}, ());
  I.Database.withConnection(
    db,
    conn => {
      let%Async _ = I.Migration.setup(conn);
      let%Async hasStatus =
        I.Migration.has(conn, ~namespace=migration.namespace);
      let%Async _ =
        !hasStatus
          ? I.Migration.upsert(
              conn,
              ~status=I.Migration.Status.make(~namespace=migration.namespace),
            )
            ->Async.mapAsync(_ => ())
          : Async.async();
      let%Async status =
        I.Migration.get(conn, ~namespace=migration.namespace);
      let status = Belt.Result.getExn(status);
      let currentVersion = I.Migration.Status.version(status);
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
          ->Belt.List.map(((_, stmt), ()) =>
              I.Connection.execute(conn, ~stmt, ~parameters=None)
              ->Async.mapAsync(_ => ())
            )
          ->Async.allInOrder;
        I.Migration.upsert(
          conn,
          ~status=I.Migration.Status.setVersion(status, ~newVersion),
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
    (module I: Db.PERSISTENCE, migrations: list(Db.Migration.t), db) => {
  migrations
  ->Belt.List.map((migration, ()) =>
      applyMigration((module I), migration, db)
    )
  ->Async.allInOrder;
};
