module Async = SihlCore_Common_Async;

module Salt = {
  type t = string;
  external toString: t => string = "%identity";
  [@bs.module "bcrypt"] external genSync: int => string = "genSaltSync";
  [@bs.module "bcrypt"] external gen: int => Async.t(string) = "genSalt";
};

module Hash = {
  type t = string;
  external toString: t => string = "%identity";
  [@bs.module "bcrypt"]
  external makeSync: (string, string) => string = "hashSync";
  [@bs.module "bcrypt"]
  external make: (string, string) => Async.t(string) = "hash";
  [@bs.module "bcrypt"]
  external compare: (~plain: string, ~hash: string) => Async.t(bool) =
    "compare";
  [@bs.module "bcrypt"]
  external compareSync: (~plain: string, ~hash: string) => bool =
    "compareSync";
  [@bs.module "bcrypt"] external getRounds: string => int = "getRounds";
};

[@bs.module "bcrypt"]
external hashAndSaltSync: (~plain: string, ~rounds: int) => Hash.t =
  "hashSync";
[@bs.module "bcrypt"]
external hashAndSalt: (~plain: string, ~rounds: int) => Async.t(Hash.t) =
  "hash";
