module Async = SihlCore_Async;
module Db = SihlCore_Db;

let getOne =
    (module I: Db.CONNECTION_INSTANCE, ~stmt, ~parameters=?, ~decode, ()) => {
  let%Async result = I.Connection.getOne(I.connection, ~stmt, ~parameters);
  Async.async(
    switch (result) {
    | Ok(result) => result |> SihlCore_Error.Decco.stringifyDecoder(decode)
    | Error(msg) =>
      Error(
        "Error happened in DB when getOne() msg="
        ++ msg
        ++ Db.debug(stmt, parameters),
      )
    },
  );
};

let getMany =
    (module I: Db.CONNECTION_INSTANCE, ~stmt, ~parameters=?, ~decode, ()) => {
  let%Async result = I.Connection.getMany(I.connection, ~stmt, ~parameters);
  switch (result) {
  | Ok((rows, meta)) =>
    let result =
      rows
      ->Belt.List.map(SihlCore_Error.Decco.stringifyDecoder(decode))
      ->Belt.List.map(result =>
          switch (result) {
          | Ok(result) => result
          | Error(msg) =>
            Db.abort(
              "Error happened in DB when getMany() msg="
              ++ msg
              ++ Db.debug(stmt, parameters),
            )
          }
        );
    Async.async((result, meta));
  | Error(msg) =>
    Db.abort(
      "Error happened in DB when getMany() msg="
      ++ msg
      ++ Db.debug(stmt, parameters),
    )
  };
};

let execute = (module I: Db.CONNECTION_INSTANCE, ~parameters=?, stmt) => {
  let%Async rows = I.Connection.execute(I.connection, ~stmt, ~parameters);
  Async.async(
    switch (rows) {
    | Ok(_) => ()
    | Error(msg) =>
      Db.abort(
        "Error happened in DB when getMany() msg="
        ++ msg
        ++ Db.debug(stmt, parameters),
      )
    },
  );
};
