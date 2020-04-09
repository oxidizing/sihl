module Async = SihlCore_Async;
module Db = SihlCore_Db;

let getOne =
    (connection: Db.connection('a, 'b), ~stmt, ~parameters=?, ~decode, ()) => {
  let%Async result = connection.getOne(connection.this, ~stmt, ~parameters);
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
    (connection: Db.connection('a, 'b), ~stmt, ~parameters=?, ~decode, ()) => {
  let%Async result = connection.getMany(connection.this, ~stmt, ~parameters);
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

let execute = (connection: Db.connection('a, 'b), ~parameters=?, stmt) => {
  let%Async rows = connection.execute(connection.this, ~stmt, ~parameters);
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
