exception ConfigurationException(string);

module Configuration = {
  // TODO use Belt.Map.String instead because Js.Dict.t is mutable
  [@decco]
  type t = Js.Dict.t(string);

  let merge = (c1, c2) => {
    c1
    ->Js.Dict.entries
    ->Belt.Array.forEach(((k, v)) => Js.Dict.set(c2, k, v));
    c2;
  };
};

module Env = {
  let processEnv: unit => Js.Json.t = [%raw
    {| function() { return process.env; } |}
  ];

  // We can not recover from not being able to read env vars
  let getAllExn = () => {
    let env =
      processEnv()->Configuration.t_decode->Common_Error.Decco.stringifyResult;
    switch (env) {
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
  module Type = {
    type condition('a) =
      | Default('a)
      | RequiredIf(string, string)
      | None;

    type choices = list(string);
    type t =
      | String(string, condition(string), choices)
      | Int(string, condition(int))
      | Bool(string, condition(bool));

    let key = type_ =>
      switch (type_) {
      | String(key, _, _) => key
      | Int(key, _) => key
      | Bool(key, _) => key
      };

    let validateString = (~key, ~value, ~choices) => {
      let choices = choices->Belt.List.toArray;
      let isInChoices =
        Belt.Array.length(choices) === 0
        || choices->Belt.Array.some(choice => choice === value);
      isInChoices
        ? Ok()
        : Error(
            {j|value not found in choices key=$(key), value=$(value), choices=$(choices)|j},
          );
    };

    let doesRequiredConfigurationExist =
        (~requiredKey, ~requiredValue, configuration: Js.Dict.t(string)) =>
      Js.Dict.get(configuration, requiredKey)
      ->Belt.Option.map(value => value === requiredValue)
      ->Belt.Option.getWithDefault(false);

    let validate = (type_, configuration) => {
      let key = key(type_);
      let value = Js.Dict.get(configuration, key);
      switch (type_, value) {
      | (String(_, Default(_), _), Some(_))
      | (String(_, Default(_), _), None) => Ok()
      | (String(_, RequiredIf(requiredKey, requiredValue), choices), value) =>
        let doesRequiredConfigurationExist =
          doesRequiredConfigurationExist(
            ~requiredKey,
            ~requiredValue,
            configuration,
          );
        switch (doesRequiredConfigurationExist, value) {
        | (true, Some(value)) => validateString(~key, ~value, ~choices)
        | (true, None) =>
          Error(
            {j|required configuration because of dependency not found requiredConfig=($(requiredKey), $(requiredValue)), key=$(key)|j},
          )
        | (false, _) => Ok()
        };
      | (String(_, None, choices), Some(value)) =>
        validateString(~key, ~value, ~choices)
      | (String(_, None, _), None) =>
        Error({j|required configuration not provided key=$(key)|j})
      | (Int(_, _), Some(value)) =>
        value
        ->int_of_string_opt
        ->Common_Error.optionAsResult(
            {j|provided configuration is not an int key=$(key), value=$(value)|j},
          )
        ->Belt.Result.map(_ => ())
      | (Int(_, None), None) =>
        Error({j|required configuration not provided key=$(key)|j})
      | (Int(_, Default(_)), None) => Ok()
      | (Int(_, RequiredIf(requiredKey, requiredValue)), _) =>
        Js.Dict.get(configuration, requiredKey)
        ->Belt.Option.map(value => value === requiredValue)
        ->Belt.Option.getWithDefault(false)
          ? Error("Failed") : Ok()
      | (Bool(_, _), Some(value)) =>
        value
        ->bool_of_string_opt
        ->Common_Error.optionAsResult(
            {j|provided configuration is not a bool key=$(key), value=$(value)|j},
          )
        ->Belt.Result.map(_ => ())
      | (Bool(_, Default(_)), None) => Ok()
      | (Bool(_, RequiredIf(requiredKey, requiredValue)), None) =>
        Js.Dict.get(configuration, requiredKey)
        ->Belt.Option.map(value => value === requiredValue)
        ->Belt.Option.getWithDefault(false)
          ? Error("Failed") : Ok()
      | (Bool(_, None), None) =>
        Error({j|required configuration is not provided key=$(key)|j})
      };
    };
  };

  type t = list(Type.t);

  let keys = schema => schema->Belt.List.map(Type.key);

  let condition = (requiredIf, default) =>
    switch (requiredIf, default) {
    | (_, Some(default)) => Type.Default(default)
    | (Some((key, value)), _) => Type.RequiredIf(key, value)
    | _ => Type.None
    };

  let string_ = (~requiredIf=?, ~default=?, ~choices=?, key) =>
    Type.String(
      key,
      condition(requiredIf, default),
      Belt.Option.getWithDefault(choices, []),
    );
  let int_ = (~requiredIf=?, ~default=?, key) =>
    Type.Int(key, condition(requiredIf, default));
  let bool_ = (~requiredIf=?, ~default=?, key) =>
    Type.Bool(key, condition(requiredIf, default));

  let validate = (schemas, configuration) => {
    schemas
    ->Belt.List.toArray
    ->Belt.List.concatMany
    ->Belt.List.map(type_ => Type.validate(type_, configuration))
    ->Belt.List.reduce(Ok(), (a, b) => Belt.Result.flatMap(a, _ => b))
    ->Belt.Result.map(_ => configuration);
  };
};

// TODO store defaults as well, right now they get lost
let configuration: Pervasives.ref(option(Configuration.t)) = ref(None);

let _get = key => (configuration^)->Belt.Option.getExn->Js.Dict.get(key);

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
    | Some("development") => env.development
    | Some("test") => env.test
    | Some("production") => env.production
    | _ => env.development
    };
  };

  let configuration = (environment: t, schemas: list(Schema.t)) => {
    let projectConfiguration = get(environment, Env.get("SIHL_ENV"));
    let environmentConfiguration = Env.getAllExn();
    let configuration =
      Configuration.merge(environmentConfiguration, projectConfiguration);
    Schema.validate(schemas, configuration);
  };
};

// TODO replace this
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
