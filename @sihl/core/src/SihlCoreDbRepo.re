module Async = SihlCoreAsync;

module Make = (Connection: SihlCoreDbCore.CONNECTION) => {
  module Result = {
    type t('a) = (list('a), SihlCoreDbCore.Result.meta);

    let metaData = ((_, metaData)) => metaData;
    let rows = ((rows, _)) => rows;
  };

  let getOne = (~connection, ~stmt, ~parameters=?, ~decode, ()) => {
    let%Async result = Connection.getOne(connection, ~stmt, ~parameters);
    Async.async(
      switch (result) {
      | Ok(result) => result |> SihlCoreError.Decco.stringifyDecoder(decode)
      | Error(msg) =>
        Error(
          "Error happened in DB when getOne() msg="
          ++ msg
          ++ SihlCoreDbCore.debug(stmt, parameters),
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
        ->Belt.List.map(SihlCoreError.Decco.stringifyDecoder(decode))
        ->Belt.List.map(result =>
            switch (result) {
            | Ok(result) => result
            | Error(msg) =>
              SihlCoreDbCore.abort(
                "Error happened in DB when getMany() msg="
                ++ msg
                ++ SihlCoreDbCore.debug(stmt, parameters),
              )
            }
          );
      Async.async((result, meta));
    | Error(msg) =>
      SihlCoreDbCore.abort(
        "Error happened in DB when getMany() msg="
        ++ msg
        ++ SihlCoreDbCore.debug(stmt, parameters),
      )
    };
  };

  let execute = (~parameters=?, connection, stmt) => {
    let%Async rows = Connection.execute(connection, ~stmt, ~parameters);
    Async.async(
      switch (rows) {
      | Ok(_) => ()
      | Error(msg) =>
        SihlCoreDbCore.abort(
          "Error happened in DB when getMany() msg="
          ++ msg
          ++ SihlCoreDbCore.debug(stmt, parameters),
        )
      },
    );
  };
};
