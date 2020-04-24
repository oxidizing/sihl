module Async = SihlCore_Async;
module Db = SihlCore_Db;
module Log = SihlCore_Log;

let applyMigration =
    (database: SihlCore_Db.database('a, 'b, 'c), migration: Db.Migration.t) => {
  let namespace = migration.namespace;
  Log.info({j|Checking migrations for app $(namespace)|j}, ());
  let%Async connection = database.connect();
  let%Async _ = connection.setupMigration(connection.this);
  let%Async hasStatus =
    connection.hasMigration(connection.this, ~namespace=migration.namespace);
  let%Async _ =
    !hasStatus
      ? connection.upsertMigration(
          connection.this,
          ~status=
            connection.makeMigration(~namespace=migration.namespace).this,
        )
        ->Async.mapAsync(_ => ())
      : Async.async();
  let%Async status =
    connection.getMigration(connection.this, ~namespace=migration.namespace);
  let status = Belt.Result.getExn(status);
  let currentVersion = status.version(status.this);
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
          connection.execute(connection.this, ~stmt, ~parameters=None)
          ->Async.mapAsync(_ => ())
        })
      ->Async.allInOrder;
    connection.upsertMigration(
      connection.this,
      ~status=status.setVersion(status.this, ~newVersion),
    )
    ->Async.mapAsync(_ =>
        Log.info(
          {j|Applied migrations for $(namespace) to reach schema version $(newVersion)|j},
          (),
        )
      )
    ->Async.let_(_ => connection.release(connection.this));
  } else {
    Log.info("No migrations to apply", ());
    Async.async();
  };
};

let applyMigrations =
    (database: Db.database('a, 'b, 'c), migrations: list(Db.Migration.t)) => {
  migrations
  ->Belt.List.map((migration, ()) => applyMigration(database, migration))
  ->Async.allInOrder;
};
