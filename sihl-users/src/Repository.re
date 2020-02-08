open Belt.Result;

module RepoResult = {
  [@decco]
  type metaData = {
    [@decco.key "FOUND_ROWS()"]
    totalCount: int,
  };
  type result('a) = ('a, metaData);
  type t('a) = result('a);

  let create = (value, metaData) => (value, metaData);
  let createWithTotal = (value, totalCount) => (
    value,
    {totalCount: totalCount},
  );
  let total = ((_, {totalCount})) => totalCount;
  let metaData = ((_, metaData)) => metaData;
  let value = ((value, _)) => value;

  let foundRowsQuery = "SELECT FOUND_ROWS();";

  let decodeMetaData = metaData_decode;
};

let getOne = (~connection, ~stmt, ~values=?, ~decode, ()) => {
  Sihl.Core.Db.Mysql.Connection.query(~connection, ~stmt, ~values, ())
  ->Future.flatMapOk(result =>
      switch (result) {
      | ([row], _) =>
        row
        |> decode
        |> Tablecloth.Result.map(Tablecloth.Option.some)
        |> Future.value
      | ([], _) => Future.value(Belt.Result.Ok(None))
      | _ =>
        let values =
          values
          |> Tablecloth.Option.map(~f=Js.Json.stringify)
          |> Tablecloth.Option.withDefault(~default="");
        Future.value(
          Belt.Result.Error(
            `ServerError(
              "Failed to parse DB response for statement "
              ++ stmt
              ++ " with values "
              ++ values,
            ),
          ),
        );
      }
    )
  ->Future.tapError(error =>
      Sihl.Core.Log.error(Sihl.Core.Error.message(error), ())
    );
};

let getMany = (~connection, ~stmt, ~values=?, ~decode, ()) => {
  Sihl.Core.Db.Mysql.Connection.query(~connection, ~stmt, ~values, ())
  ->Future.flatMapOk(result =>
      switch (result) {
      | (rows, _) =>
        let mainResult =
          Tablecloth.List.map(~f=x => x |> decode, rows)
          |> Tablecloth.Result.combine
          |> Future.value;
        mainResult->Future.flatMapOk(mainResult =>
          Sihl.Core.Db.Mysql.Connection.query(
            ~connection,
            ~stmt=RepoResult.foundRowsQuery,
            ~values=None,
            (),
          )
          ->Future.flatMapOk(result =>
              switch (result) {
              | ([row], _) =>
                row
                |> RepoResult.decodeMetaData
                |> Sihl.Core.Error.decodeToServerError
                |> Future.value
              | _ =>
                Future.value(
                  Belt.Result.Error(
                    `ServerError("Could no fetch FOUND_ROWS()"),
                  ),
                )
              }
            )
          ->Future.mapOk(RepoResult.create(mainResult))
        );
      }
    )
  ->Future.tapError(error =>
      Sihl.Core.Log.error(Sihl.Core.Error.message(error), ())
    );
};

let (<$>) = Future.(<$>);

module User = {
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
