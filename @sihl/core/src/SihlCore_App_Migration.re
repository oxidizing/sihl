module Async = SihlCore_Common_Async;

let applyMigration =
    (
      module I: SihlCore_Common_Db.PERSISTENCE,
      migration: SihlCore_Common_Db.Migration.t,
      db,
    ) => {
  let namespace = migration.namespace;
  SihlCore_Common.Log.info(
    {j|Checking migrations for app $(namespace)|j},
    (),
  );
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
      let steps =
        SihlCore_Common_Db.Migration.stepsToApply(migration, currentVersion);
      let newVersion = SihlCore_Common_Db.Migration.maxVersion(steps);
      let nrSteps = steps |> Belt.List.length;
      if (nrSteps > 0) {
        SihlCore_Common.Log.info(
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
            SihlCore_Common.Log.info(
              {j|Applied migrations for $(namespace) to reach schema version $(newVersion)|j},
              (),
            )
          );
      } else {
        SihlCore_Common.Log.info("No migrations to apply", ());
        Async.async();
      };
    },
  );
};

let applyMigrations =
    (
      module I: SihlCore_Common.Db.PERSISTENCE,
      migrations: list(SihlCore_Common_Db.Migration.t),
      db,
    ) => {
  migrations
  ->Belt.List.map((migration, ()) =>
      applyMigration((module I), migration, db)
    )
  ->Async.allInOrder;
};
