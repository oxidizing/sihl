exception EnvironmentConfigurationException(string);

module Env = {
  let getAll: unit => Js.Json.t = [%raw
    {| function() { return process.env; } |}
  ];

  let get = key => {
    getAll()
    ->Js.Json.decodeObject
    ->Belt.Option.flatMap(o => Js.Dict.get(o, key))
    ->Belt.Option.flatMap(Js.Json.decodeString);
  };

  let getExn = key => {
    switch (get(key)) {
    | Some(env) => env
    | None =>
      raise(
        EnvironmentConfigurationException(
          "Environment variable not found key=" ++ key,
        ),
      )
    };
  };
};

module Configuration = {
  type t = list((string, string));
};

module Environment = {
  type t = {
    development: Configuration.t,
    test: Configuration.t,
    production: Configuration.t,
  };

  let get = e => {
    e.test;
  };
};

module Db = {
  module Url = {
    type t = string;

    let readFromEnv = () => {
      Env.getExn("DATABASE_URL");
    };

    let parse = url => {
      // TODO make sure this works for other databases as well
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

// TODO take configuration schema as first parameter
let _get = k => {
  Env.getAll()
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
