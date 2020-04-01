module Async = SihlCoreAsync;

[@bs.module]
external random: (~nBytes: int, ~encoding: string) => Js.Promise.t(string) =
  "./crypt/random-bytes.js";

let hex = (~nBytes) => random(~nBytes, ~encoding="hex");
