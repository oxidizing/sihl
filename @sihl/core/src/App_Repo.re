module Async = Common_Async;

module Make = (Persistence: Common_Db.PERSISTENCE) => {
  module Connection = Persistence.Connection;
  module Database = Persistence.Database;
  module Migration = Persistence.Migration;

  let getOne = (~connection, ~stmt, ~parameters=?, ~decode, ()) => {
    let%Async result = Connection.getOne(connection, ~stmt, ~parameters);
    Async.async(
      switch (result) {
      | Ok(result) => result |> Common_Error.Decco.stringifyDecoder(decode)
      | Error(msg) =>
        Error(
          "Error happened in DB when getOne() msg="
          ++ msg
          ++ Common_Db.debug(stmt, parameters),
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
        ->Belt.List.map(Common_Error.Decco.stringifyDecoder(decode))
        ->Belt.List.map(result =>
            switch (result) {
            | Ok(result) => result
            | Error(msg) =>
              Common_Db.abort(
                "Error happened in DB when getMany() msg="
                ++ msg
                ++ Common_Db.debug(stmt, parameters),
              )
            }
          );
      Async.async((result, meta));
    | Error(msg) =>
      Common_Db.abort(
        "Error happened in DB when getMany() msg="
        ++ msg
        ++ Common_Db.debug(stmt, parameters),
      )
    };
  };

  let execute = (~parameters=?, connection, stmt) => {
    let%Async rows = Connection.execute(connection, ~stmt, ~parameters);
    Async.async(
      switch (rows) {
      | Ok(_) => ()
      | Error(msg) =>
        Common_Db.abort(
          "Error happened in DB when getMany() msg="
          ++ msg
          ++ Common_Db.debug(stmt, parameters),
        )
      },
    );
  };
};
