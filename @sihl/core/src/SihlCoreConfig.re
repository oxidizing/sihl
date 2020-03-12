module Env = {
  let get: unit => Js.Json.t = [%raw {| function() { return process.env; } |}];
};

module Db = {
  [@decco]
  type t = {
    [@decco.key "DB_USER"]
    dbUser: string,
    [@decco.key "DB_HOST"]
    dbHost: string,
    [@decco.key "DB_NAME"]
    dbName: string,
    [@decco.key "DB_PASSWORD"]
    dbPassword: string,
    [@decco.key "DB_PORT"]
    // TODO implement custom encoder/decoder for int as string
    dbPort: string,
    [@decco.key "DB_QUEUE_LIMIT"] [@decco.default "300"]
    queueLimit: string,
    [@decco.key "DB_CONNECTION_LIMIT"] [@decco.default "8"]
    connectionLimit: string,
  };

  let read = () => {
    Env.get() |> t_decode;
  };
};

// TODO get rid of decoded record approach and evaluate GADT vs string lookup
// TODO provide configs for development, production, test

let get = key => "";

/* module TestingGround = { */
/*   type backend = */
/*     | Console */
/*     | Smtp; */

/*   type config('a) = */
/*     | EmailBackend(backend): config(backend) */
/*     | Float(float): config(float) */
/*     | Bool(bool): config(bool) */
/*     | Str(string): config(string); */

/*   let eval: type a. config(a) => a = */
/*     fun */
/*     | EmailBackend(i) => i */
/*     | Float(f) => f */
/*     | Bool(b) => b */
/*     | Str(s) => s; */
/* }; */

/* let test = TestingGround.eval(EmailBackend(Console)); */
