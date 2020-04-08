module Async = SihlCore_Common.Async;

let getOne =
    (
      module I: SihlCore_Common_Db.PERSISTENCE,
      ~connection,
      ~stmt,
      ~parameters=?,
      ~decode,
      (),
    ) => {
  let%Async result = I.Connection.getOne(connection, ~stmt, ~parameters);
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

let getMany =
    (
      module I: SihlCore_Common_Db.PERSISTENCE,
      ~connection,
      ~stmt,
      ~parameters=?,
      ~decode,
      (),
    ) => {
  let%Async result = I.Connection.getMany(connection, ~stmt, ~parameters);
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

let execute =
    (
      module I: SihlCore_Common_Db.PERSISTENCE,
      ~parameters=?,
      ~connection,
      stmt,
    ) => {
  let%Async rows = I.Connection.execute(connection, ~stmt, ~parameters);
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
