module Env = {
  let get: unit => Js.Json.t = [%raw {| function() { return process.env; } |}];
};

module Environment = {
  type configuration = list((string, string));

  type t = {
    development: configuration,
    test: configuration,
    production: configuration,
  };

  let get = e => {
    e.test;
  };
};
module Db = {
  module Url = {
    [@decco]
    type env = {
      [@decco.key "DATABASE_URL"]
      url: string,
    };

    type t = string;

    let readFromEnv = () => {
      let {url} =
        Env.get()
        |> env_decode
        |> SihlCoreError.Decco.stringifyResult
        |> SihlCoreError.failIfError;
      url;
    };

    let parse = url => {
      switch (
        url |> Js.String.replace("mysql://", "") |> Js.String.split("@")
      ) {
      | [|credentials, hostAndDb|] =>
        switch (Js.String.split(":", credentials)) {
        | [|user, password|] =>
          switch (Js.String.split(":", hostAndDb)) {
          | [|host, portAndDb|] =>
            switch (Js.String.split("/", portAndDb)) {
            | [|port, db|] => Ok((user, password, host, port, db))
            | _ => Error("Invalid database url provided")
            }
          | _ => Error("Invalid database url provided")
          }
        | _ => Error("Invalid database url provided")
        }
      | _ => Error("Invalid database url provided")
      };
    };
  };

  type t = {
    dbUser: string,
    dbHost: string,
    dbName: string,
    dbPassword: string,
    dbPort: string,
    queueLimit: string,
    connectionLimit: string,
  };

  let make = (~user, ~host, ~db, ~password, ~port) => {
    {
      dbUser: user,
      dbHost: host,
      dbName: db,
      dbPassword: password,
      dbPort: port,
      queueLimit: "300",
      connectionLimit: "8",
    };
  };

  let makeFromUrl = (url: Url.t) => {
    url
    ->Url.parse
    ->Belt.Result.map(((user, password, host, port, db)) =>
        make(~user, ~password, ~host, ~port, ~db)
      );
  };
};

module Schema = {
  type type_ =
    | String(string, option(string), list(string))
    | Int(string, option(int))
    | Bool(string, option(bool));
  type t = list(type_);

  let string_ = (~default=?, ~choices=?, key) =>
    String(key, default, Belt.Option.getWithDefault(choices, []));
  let int_ = (~default=?, key) => Int(key, default);
  let bool_ = (~default=?, key) => Bool(key, default);
};

exception EnvironmentConfigurationException(string);

// TODO take configuration schema as first parameter
let _get = k => {
  Env.get()
  ->Js.Json.decodeObject
  ->Belt.Option.flatMap(o => Js.Dict.get(o, k))
  ->Belt.Option.flatMap(Js.Json.decodeString);
};

let get = (~default=?, k) => {
  switch (_get(k), default) {
  | (Some(env), _) => env
  | (None, Some(default)) => default
  | _ =>
    raise(
      EnvironmentConfigurationException(
        "Env var not found and no default provided for key= " ++ k,
      ),
    )
  };
};

let getInt = (~default=?, k) => {
  let env = k->_get->Belt.Option.flatMap(int_of_string_opt);
  switch (env, default) {
  | (Some(env), _) => env
  | (None, Some(default)) => default
  | _ =>
    raise(
      EnvironmentConfigurationException(
        "Env var not found and no default provided for key= " ++ k,
      ),
    )
  };
};

let getBool = (~default=?, k) => {
  let env = k->_get->Belt.Option.flatMap(bool_of_string_opt);
  switch (env, default) {
  | (Some(env), _) => env
  | (None, Some(default)) => default
  | _ =>
    raise(
      EnvironmentConfigurationException(
        "Env var not found and no default provided for key= " ++ k,
      ),
    )
  };
};
