module Async = SihlCoreAsync;

module Result = {
  module MetaData = {
    [@decco]
    type t = {
      [@decco.key "FOUND_ROWS()"]
      totalCount: int,
    };
  };

  type t('a) = (list('a), MetaData.t);

  let create = (rows, metaData) => (rows, metaData);
  let createWithTotal = (value, totalCount) => (
    value,
    MetaData.{totalCount: totalCount},
  );
  let total = ((_, MetaData.{totalCount})) => totalCount;
  let metaData = ((_, metaData)) => metaData;
  let rows = ((rows, _)) => rows;

  let foundRowsQuery = "SELECT FOUND_ROWS();";
};

let debug = (stmt, parameters) => {
  "for stmt="
  ++ stmt
  ++ Belt.Option.mapWithDefault(parameters, "", parameters =>
       " with params=" ++ Js.Json.stringify(parameters)
     );
};

let getOne = (~connection, ~stmt, ~parameters=?, ~decode, ()) => {
  let%Async result =
    SihlCoreDbMysql.Connection.query(~connection, ~stmt, ~parameters);
  Async.async(
    switch (result) {
    | Ok(([row], _)) => row |> SihlCoreError.Decco.stringifyDecoder(decode)
    | Ok(([], _)) =>
      Error("No rows found in database " ++ debug(stmt, parameters))
    | Ok(_) =>
      Error(
        "Two or more rows found when we were expecting only one "
        ++ debug(stmt, parameters),
      )
    | Error(msg) =>
      SihlCoreDbError.abort(
        "Error happened in DB when getOne() msg="
        ++ msg
        ++ debug(stmt, parameters),
      )
    },
  );
};

let getMany = (~connection, ~stmt, ~parameters=?, ~decode, ()) => {
  let%Async result =
    SihlCoreDbMysql.Connection.query(~connection, ~stmt, ~parameters);
  switch (result) {
  | Ok((rows, _)) =>
    let result =
      rows
      ->Belt.List.map(SihlCoreError.Decco.stringifyDecoder(decode))
      ->Belt.List.map(result =>
          switch (result) {
          | Ok(result) => result
          | Error(msg) =>
            SihlCoreDbError.abort(
              "Error happened in DB when getMany() msg="
              ++ msg
              ++ debug(stmt, parameters),
            )
          }
        );
    let%Async meta =
      SihlCoreDbMysql.Connection.query(
        ~connection,
        ~stmt=Result.foundRowsQuery,
        ~parameters=None,
      );
    let meta =
      switch (meta) {
      | Ok(([row], _)) =>
        switch (
          row
          |> SihlCoreError.Decco.stringifyDecoder(Result.MetaData.t_decode)
        ) {
        | Ok(meta) => meta
        | Error(_) =>
          SihlCoreDbError.abort(
            "Error happened in DB when decoding meta "
            ++ debug(stmt, parameters),
          )
        }
      | _ =>
        SihlCoreDbError.abort(
          "Error happened in DB when fetching FOUND_ROWS() "
          ++ debug(stmt, parameters),
        )
      };
    Async.async @@ Result.create(result, meta);
  | Error(msg) =>
    SihlCoreDbError.abort(
      "Error happened in DB when getMany() msg="
      ++ msg
      ++ debug(stmt, parameters),
    )
  };
};

let execute = (~parameters=?, connection, stmt) => {
  let%Async rows =
    SihlCoreDbMysql.Connection.execute(~connection, ~stmt, ~parameters);
  Async.async(
    switch (rows) {
    | Ok(_) => ()
    | Error(msg) =>
      SihlCoreDbError.abort(
        "Error happened in DB when getMany() msg="
        ++ msg
        ++ debug(stmt, parameters),
      )
    },
  );
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
