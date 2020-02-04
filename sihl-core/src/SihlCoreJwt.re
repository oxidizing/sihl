let deccoToClientError = future =>
  switch (future) {
  | Belt.Result.Ok(_) as result => result
  | Belt.Result.Error({Decco.path, Decco.message, Decco.value}) =>
    Belt.Result.Error(
      `ServerError(
        "Failed to decode at "
        ++ path
        ++ ", "
        ++ message
        ++ ", got "
        ++ Js.Json.stringify(value),
      ),
    )
  };

module Plain = {
  [@decco]
  type t = {
    exp: float,
    typ: option(string),
    sub: option(string),
  };

  let make = (exp, ~typ=?, ~sub=?, ()) => {exp, typ, sub};

  let decode = t_decode;
  let encode = t_encode;
};

module Signed = {
  [@decco]
  type t = string;
};

[@bs.module "jsonwebtoken"]
external sign: (Js.Json.t, string) => string = "sign";
let sign: (Plain.t, string) => Signed.t =
  (token, secret) => token->Plain.encode->sign(secret);

[@bs.module "jsonwebtoken"]
external verify: (string, string) => Js.Json.t = "verify";
let verify: (Signed.t, string) => Belt.Result.t(Plain.t, string) =
  (token, secret) => {
    switch (verify(token, secret)) {
    | exception (Js.Exn.Error(err)) =>
      let message = Js.Exn.message(err);
      Belt.Result.Error(
        Belt.Option.getWithDefault(message, "Failed to verify jwt token"),
      );
    | value =>
      switch (value |> Plain.decode |> deccoToClientError) {
      | Belt.Result.Ok(_) as r => r
      | Belt.Result.Error(error) =>
        Belt.Result.Error(SihlCoreError.message(error))
      }
    };
  };

let mightBeJwtToken = token =>
  token |> Tablecloth.String.startsWith(~prefix="ey");

let verifyToken = (token, ~secret) => {
  Future.value(verify(token, secret))
  ->Future.tapError(err => SihlCoreLog.error(err, ()))
  ->Future.mapError(_ => `AuthenticationError("Failed to verify jwt token"));
};

let isVerifyableToken = (~secret, token) =>
  switch (verify(token, secret)) {
  | Belt.Result.Ok(_) => true
  | Belt.Result.Error(_) => false
  };

module PasswordReset = {
  let hourSeconds = 60.0 *. 60.0;

  let create = (~userId, ~secret) => {
    let token =
      Plain.make(
        SihlCoreDate.unixSeconds() +. hourSeconds,
        ~typ="pw",
        ~sub=userId,
        (),
      );
    sign(token, secret);
  };
};

module Auth = {
  let weekSeconds = 7.0 *. 24.0 *. 60.0 *. 60.0;

  let create = (~userId, ~secret) => {
    let token =
      Plain.make(
        SihlCoreDate.unixSeconds() +. weekSeconds,
        ~typ="auth",
        ~sub=userId,
        (),
      );
    sign(token, secret);
  };

  let isAuthToken = (token, ~secret) => {
    Tablecloth.(
      verifyToken(token, ~secret)
      ->Future.mapOk(token =>
          token.typ
          |> Option.map(~f=t => t === "auth")
          |> Option.withDefault(~default=false)
        )
    );
  };
};
