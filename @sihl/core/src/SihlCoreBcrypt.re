module Salt = {
  type t = string;
  external toString: t => string = "%identity";
  [@bs.module "bcrypt"] external genSaltSync_: int => string = "genSaltSync";
  [@bs.module "bcrypt"]
  external genSalt_: int => Js.Promise.t(string) = "genSalt";
  let genSync = (~rounds: int=10, ()) => genSaltSync_(rounds);
  let gen = (~rounds: int=10, ()) => genSalt_(rounds);
};

module Hash = {
  type t = string;
  external toString: t => string = "%identity";
  [@bs.module "bcrypt"]
  external makeSync: (string, string) => string = "hashSync";
  [@bs.module "bcrypt"]
  external make: (string, string) => Js.Promise.t(string) = "hash";
  [@bs.module "bcrypt"]
  external compare_: (string, string) => Js.Promise.t(bool) = "compare";
  let compare = (a, b) => compare_(a, b);
  [@bs.module "bcrypt"]
  external compareSync: (string, string) => bool = "compareSync";
  [@bs.module "bcrypt"] external getRounds: string => int = "getRounds";
};

[@bs.module "bcrypt"]
external hashAndSaltSync_: (string, int) => string = "hashSync";

let hashAndSaltSync = (~rounds=10, data) => hashAndSaltSync_(data, rounds);

[@bs.module "bcrypt"]
external hashAndSalt_: (string, int) => Js.Promise.t(string) = "hash";

let hashAndSalt = (~rounds=10, data) => hashAndSalt_(data, rounds);
