// Using Bluebird for the global promise implementation allows actually useful
// stack traces to be generated for debugging runtime issues.
%bs.raw
{|global.Promise = require('bluebird')|};
%bs.raw
{|
Promise.config({
  warnings: false
})
|};

open SihlCore.SihlCoreDbCore;
module Error = SihlCore.SihlCore.Error;
module Log = SihlCore.SihlCore.Log;

[@bs.module "mysql2/promise"]
external setup: Config.t => Database.t = "createPool";
[@bs.send] external end_: Database.t => unit = "end";
[@bs.send]
external connect: Database.t => Js.Promise.t(Connection.t) = "getConnection";
[@bs.send] external release: Connection.t => unit = "release";

[@bs.send]
external query_: (Connection.t, string, Js.Json.t) => Js.Promise.t(Js.Json.t) =
  "query";
