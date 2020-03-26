module Async = SihlCoreAsync;

module Make = (Persistence: SihlCoreDbCore.PERSISTENCE) => {
  module Result = {
    type t('a) = (list('a), SihlCoreDbCore.Result.meta);

    let metaData = ((_, metaData)) => metaData;
    let rows = ((rows, _)) => rows;
  };

  let getOne = (~connection, ~stmt, ~parameters=?, ~decode, ()) => {
    let%Async result =
      Persistence.Connection.querySimple(connection, ~stmt, ~parameters);
    Async.async(
      switch (result) {
      | Ok([row]) => row |> SihlCoreError.Decco.stringifyDecoder(decode)
      | Ok([]) =>
        Error(
          "No rows found in database "
          ++ SihlCoreDbCore.debug(stmt, parameters),
        )
      | Ok(_) =>
        Error(
          "Two or more rows found when we were expecting only one "
          ++ SihlCoreDbCore.debug(stmt, parameters),
        )
      | Error(msg) =>
        SihlCoreDbCore.abort(
          "Error happened in DB when getOne() msg="
          ++ msg
          ++ SihlCoreDbCore.debug(stmt, parameters),
        )
      },
    );
  };

  let getMany = (~connection, ~stmt, ~parameters=?, ~decode, ()) => {
    let%Async result =
      Persistence.Connection.query(connection, ~stmt, ~parameters);
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
    let%Async rows =
      Persistence.Connection.execute(connection, ~stmt, ~parameters);
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

// taken from caqti make use of GADT
/* type field(_) = */
/*   | Bool: field(bool) */
/*   | Int: field(int) */
/*   | Float: field(float) */
/*   | String: field(string); */

/* type t(_) = */
/*   | Unit: t(unit) */
/*   | Field(field('a)): t('a) */
/*   | Option(t('a)): t(option('a)) */
/*   | Tup2(t('a0), t('a1)): t(('a0, 'a1)) */
/*   | Tup3(t('a0), t('a1), t('a2)): t(('a0, 'a1, 'a2)) */
/*   | Tup4(t('a0), t('a1), t('a2), t('a3)): t(('a0, 'a1, 'a2, 'a3)); */

/* module Std = { */
/*   let unit = Unit; */
/*   let option = t => Option(t); */
/*   let tup2 = (t0, t1) => Tup2(t0, t1); */
/*   let tup3 = (t0, t1, t2) => Tup3(t0, t1, t2); */
/*   let tup4 = (t0, t1, t2, t3) => Tup4(t0, t1, t2, t3); */
/*   let bool = Field(Bool); */
/*   let int = Field(Int); */
/*   let float = Field(Float); */
/*   let string = Field(String); */
/* }; */

/* let test = Std.tup2(Std.bool, Std.int); */
