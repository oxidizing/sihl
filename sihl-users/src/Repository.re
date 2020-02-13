module Async = Sihl.Core.Async;

// TODO move to sihl-core
module Repo = {
  module RepoResult = {
    module MetaData = {
      [@decco]
      type t = {
        [@decco.key "FOUND_ROWS()"]
        totalCount: int,
      };

      let decode = t_decode;
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

  let getOne = (~connection, ~stmt, ~parameters=?, ~decode, ()) => {
    let%Async result =
      Sihl.Core.Db.Mysql.Connection.query(~connection, ~stmt, ~parameters);
    let result = Sihl.Core.Db.failIfError(result);
    switch (result) {
    | ([row], _) =>
      row
      |> Sihl.Core.Error.Decco.stringifyDecoder(decode)
      |> Sihl.Core.Db.failIfError
      |> Async.async
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
          |> Sihl.Core.Error.Decco.stringifyDecoder(
               RepoResult.MetaData.decode,
             )
          |> Sihl.Core.Db.failIfError
        | _ => Sihl.Core.Db.fail("Could not fetch FOUND_ROWS()")
        };
      Async.async @@ RepoResult.create(result, meta);
    };
  };

  let execute = (~parameters=?, ~connection, stmt) =>
    Sihl.Core.Db.fail("Not implemented");
};

module User = {
  module Clean = {
    let stmt = "
TRUNCATE TABLE users;
";
    let run: Sihl.Core.Db.Connection.t => Js.Promise.t(unit) =
      connection => Repo.execute(~connection, stmt);
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

    let query:
      Sihl.Core.Db.Connection.t =>
      Js.Promise.t(Repo.RepoResult.t(Model.User.t)) =
      connection =>
        Repo.getMany(~connection, ~stmt, ~decode=Model.User.t_decode, ());
  };

  module Get = {
    let stmt = "SELECT
  uuid_of(uuid) as uuid,
  email,
  password,
  given_name,
  family_name,
  username,
  phone,
  status
FROM users
WHERE uuid = UNHEX(REPLACE(?, '-', ''));
";

    [@decco]
    type parameters = string;
    let encode = parameters_encode;

    let query:
      (Sihl.Core.Db.Connection.t, ~userId: string) =>
      Js.Promise.t(Model.User.t) =
      (connection, ~userId) =>
        Repo.getOne(
          ~connection,
          ~stmt,
          ~parameters=encode(userId),
          ~decode=Model.User.t_decode,
          (),
        );
  };

  module GetByEmail = {
    let stmt = "SELECT
  uuid_of(uuid) as uuid,
  email,
  password,
  given_name,
  family_name,
  username,
  phone,
  status
FROM users
WHERE email = ?;
";

    [@decco]
    type parameters = string;
    let encode = parameters_encode;

    let query:
      (Sihl.Core.Db.Connection.t, ~email: string) =>
      Js.Promise.t(Model.User.t) =
      (connection, ~email) =>
        Repo.getOne(
          ~connection,
          ~stmt,
          ~parameters=encode(email),
          ~decode=Model.User.t_decode,
          (),
        );
  };

  module Store = {
    let stmt = "";

    [@decco]
    type parameters = string;
    let encode = parameters_encode;

    let query = (connection, ~user) =>
      Repo.execute(~parameters=encode("hey"), ~connection, stmt);
  };
};

module Token = {
  module Store = {
    let stmt = "";

    [@decco]
    type parameters = string;
    let encode = parameters_encode;

    let query = (connection, ~token) =>
      Repo.execute(encode("hoo"), ~connection, ~stmt);
  };

  module Get = {
    let stmt = "SELECT
  uuid_of(uuid) as uuid,
  userId,
  token
FROM tokens
WHERE token = ?;
";

    [@decco]
    type parameters = string;
    let encode = parameters_encode;

    let query:
      (Sihl.Core.Db.Connection.t, ~tokenString: string) =>
      Js.Promise.t(Model.Token.t) =
      (connection, ~tokenString) =>
        Repo.getOne(
          ~connection,
          ~stmt,
          ~parameters=encode(tokenString),
          ~decode=Model.Token.t_decode,
          (),
        );
  };
};
