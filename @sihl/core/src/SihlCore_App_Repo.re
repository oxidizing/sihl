module Async = SihlCore_Common.Async;

module Make = (Persistence: SihlCore_Common.Db.PERSISTENCE) => {
  module Connection = Persistence.Connection;
  module Database = Persistence.Database;
  module Migration = Persistence.Migration;

  let getOne = (~connection, ~stmt, ~parameters=?, ~decode, ()) => {
    let%Async result = Connection.getOne(connection, ~stmt, ~parameters);
    Async.async(
      switch (result) {
      | Ok(result) =>
        result |> SihlCore_Common.Error.Decco.stringifyDecoder(decode)
      | Error(msg) =>
        Error(
          "Error happened in DB when getOne() msg="
          ++ msg
          ++ SihlCore_Common.Db.debug(stmt, parameters),
        )
      },
    );
  };

  let getMany = (~connection, ~stmt, ~parameters=?, ~decode, ()) => {
    let%Async result = Connection.getMany(connection, ~stmt, ~parameters);
    switch (result) {
    | Ok((rows, meta)) =>
      let result =
        rows
        ->Belt.List.map(SihlCore_Common.Error.Decco.stringifyDecoder(decode))
        ->Belt.List.map(result =>
            switch (result) {
            | Ok(result) => result
            | Error(msg) =>
              SihlCore_Common.Db.abort(
                "Error happened in DB when getMany() msg="
                ++ msg
                ++ SihlCore_Common.Db.debug(stmt, parameters),
              )
            }
          );
      Async.async((result, meta));
    | Error(msg) =>
      SihlCore_Common.Db.abort(
        "Error happened in DB when getMany() msg="
        ++ msg
        ++ SihlCore_Common.Db.debug(stmt, parameters),
      )
    };
  };

  let execute = (~parameters=?, connection, stmt) => {
    let%Async rows = Connection.execute(connection, ~stmt, ~parameters);
    Async.async(
      switch (rows) {
      | Ok(_) => ()
      | Error(msg) =>
        SihlCore_Common.Db.abort(
          "Error happened in DB when getMany() msg="
          ++ msg
          ++ SihlCore_Common.Db.debug(stmt, parameters),
        )
      },
    );
  };
};
