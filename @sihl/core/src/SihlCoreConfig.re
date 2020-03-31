exception ConfigurationException(string);

module Configuration = {
  [@decco]
  type t = Js.Dict.t(string);

  let merge = (c1, c2) => {
    let s1 =
      c1
      ->Js.Dict.entries
      ->Belt.Array.map(((k, _)) => k)
      ->Belt.Set.String.fromArray;
    let s2 =
      c2
      ->Js.Dict.entries
      ->Belt.Array.map(((k, _)) => k)
      ->Belt.Set.String.fromArray;
    let intersection = Belt.Set.String.intersect(s1, s2);
    if (!Belt.Set.String.isEmpty(intersection)) {
      Error(
        "Can not merge configurations, found duplicate configuration="
        ++ (
          intersection |> Belt.Set.String.toArray |> Js.Array.joinWith(", ")
        ),
      );
    } else {
      c1
      ->Js.Dict.entries
      ->Belt.Array.forEach(((k, v)) => Js.Dict.set(c2, k, v));
      Ok(c2);
    };
  };
};

module Env = {
  let processEnv: unit => Js.Json.t = [%raw
    {| function() { return process.env; } |}
  ];

  // We can not recover from not being able to read env vars
  let getAllExn = () => {
    switch (
      processEnv()->Configuration.t_decode->SihlCoreError.Decco.stringifyResult
    ) {
    | Ok(env) => env
    | Error(msg) =>
      raise(ConfigurationException("Can not get process.env msg=" ++ msg))
    };
  };

  let get = key => Js.Dict.get(getAllExn(), key);

  let getExn = key => {
    switch (get(key)) {
    | Some(env) => env
    | None =>
      raise(
        ConfigurationException("Environment variable not found key=" ++ key),
      )
    };
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

  let validate = (schemas, configuration) => {
    // TODO implement
    Ok(configuration);
  };
};

let _get = key => Js.Dict.get(Env.getAllExn(), key);

let get = (~default=?, key) => {
  switch (_get(key), default) {
  | (Some(env), _) => env
  | (None, Some(default)) => default
  | _ =>
    raise(
      ConfigurationException(
        "Env var not found and no default provided for key= " ++ key,
      ),
    )
  };
};

let getInt = (~default=?, key) => {
  let env = key->_get->Belt.Option.flatMap(int_of_string_opt);
  switch (env, default) {
  | (Some(env), _) => env
  | (None, Some(default)) => default
  | _ =>
    raise(
      ConfigurationException(
        "Env var not found and no default provided for key= " ++ key,
      ),
    )
  };
};

let getBool = (~default=?, key) => {
  let env = key->_get->Belt.Option.flatMap(bool_of_string_opt);
  switch (env, default) {
  | (Some(env), _) => env
  | (None, Some(default)) => default
  | _ =>
    raise(
      ConfigurationException(
        "Env var not found and no default provided for key= " ++ key,
      ),
    )
  };
};

module Environment = {
  type t = {
    development: Configuration.t,
    test: Configuration.t,
    production: Configuration.t,
  };

  let make = (~development, ~test, ~production) => {
    {
      development: Js.Dict.fromList(development),
      test: Js.Dict.fromList(test),
      production: Js.Dict.fromList(production),
    };
  };

  let get = (env, sihlEnv) => {
    switch (sihlEnv) {
    | "development" => env.development
    | "test" => env.test
    | "production" => env.production
    | _ => env.development
    };
  };

  let configuration = (environment: t, schemas: list(Schema.t)) => {
    let projectConfiguration = get(environment, Env.getExn("SIHL_ENV"));
    let environmentConfiguration = Env.getAllExn();
    Configuration.merge(environmentConfiguration, projectConfiguration)
    ->Belt.Result.flatMap(Schema.validate(schemas));
  };
};

module Db = {
  module Url = {
    type t = string;

    let readFromEnv = () => Env.getExn("DATABASE_URL");

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
