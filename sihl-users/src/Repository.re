module Async = Sihl.Core.Async;

// TODO move to sihl-core
module RepoResult = {
  module MetaData = {
    [@decco]
    type t = {
      [@decco.key "FOUND_ROWS()"]
      totalCount: int,
    };

    let decode = t_decode;
  };
  type result('a) = ('a, MetaData.t);
  type t('a) = result('a);

  let create = (value, metaData) => (value, metaData);
  let createWithTotal = (value, totalCount) => (
    value,
    MetaData.{totalCount: totalCount},
  );
  let total = ((_, MetaData.{totalCount})) => totalCount;
  let metaData = ((_, metaData)) => metaData;
  let value = ((value, _)) => value;

  let foundRowsQuery = "SELECT FOUND_ROWS();";
};

let getOne = (~connection, ~stmt, ~parameters=?, ~decode, ()) => {
  let%Async result =
    Sihl.Core.Db.Mysql.Connection.query(~connection, ~stmt, ~parameters);
  let result = Sihl.Core.Db.failIfError(result);
  switch (result) {
  | ([row], _) =>
    row
    |> Sihl.Core.Error.Decco.stringifyDecoder(decode)
    |> Sihl.Core.Db.failIfError
  | ([], _) => Sihl.Core.Db.fail("No rows found in database")
  | _ =>
    Sihl.Core.Db.fail(
      "Two or more rows found when we were expecting only one",
    )
  };
};

let getMany = (~connection, ~stmt, ~parameters=?, ~decode, ()) => {
  let%Async result =
    Sihl.Core.Db.Mysql.Connection.query(~connection, ~stmt, ~parameters);
  switch (Sihl.Core.Db.failIfError(result)) {
  | (rows, _) =>
    let result =
      rows
      ->Belt.List.map(Sihl.Core.Error.Decco.stringifyDecoder(decode))
      ->Belt.List.map(Sihl.Core.Db.failIfError);
    let%Async meta =
      Sihl.Core.Db.Mysql.Connection.query(
        ~connection,
        ~stmt=RepoResult.foundRowsQuery,
        ~parameters=None,
      );
    let meta =
      switch (Sihl.Core.Db.failIfError(meta)) {
      | ([row], _) =>
        row
        |> Sihl.Core.Error.Decco.stringifyDecoder(RepoResult.MetaData.decode)
        |> Sihl.Core.Db.failIfError
      | _ => Sihl.Core.Db.fail("Could not fetch FOUND_ROWS()")
      };
    Async.async @@ RepoResult.create(result, meta);
  };
};

let execute = (~connection, ~stmt) =>
  Future.value(
    Belt.Result.Error(`ServerError("Repository.execute() Not implemented")),
  );

module User = {
  let (<$>) = Future.(<$>);
  module Clean = {
    let stmt = "
TRUNCATE TABLE users;
";
    let run:
      Sihl.Core.Db.Connection.t =>
      Future.t(Belt.Result.t(unit, Sihl.Core.Error.t)) =
      connection => execute(~connection, ~stmt);
  };

  module GetAll = {
    let stmt = "
SELECT
  uuid_of(uuid) as uuid,
  email,
  password,
  given_name,
  family_name,
  username,
  phone,
  status
FROM users;
";
    let encode = value => [|value|] |> Json.Encode.stringArray;
    let query:
      Sihl.Core.Db.Connection.t =>
      Future.t(Belt.Result.t(list(Model.User.t), Sihl.Core.Error.t)) =
      connection =>
        getMany(~connection, ~stmt, ~decode=Model.User.decode, ())
        <$> RepoResult.value;
  };

  module Get = {
    let stmt = "";
    let encode = () => ();
    let query:
      (Sihl.Core.Db.Connection.t, ~userId: string) =>
      Future.t(Belt.Result.t(Model.User.t, Sihl.Core.Error.t)) =
      (connection, ~userId) =>
        Belt.Result.Error(`ClientError("Not found"))->Future.value;
  };
};
