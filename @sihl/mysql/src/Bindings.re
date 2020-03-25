module Async = Sihl.Core.Async;

[@bs.module "mysql2/promise"]
external setup: Sihl.Core.Db.Config.t => Sihl.Core.Db.Database.t =
  "createPool";
[@bs.send] external end_: Sihl.Core.Db.Database.t => unit = "end";
[@bs.send]
external connect:
  Sihl.Core.Db.Database.t => Async.t(Sihl.Core.Db.Connection.t) =
  "getConnection";
[@bs.send] external release: Sihl.Core.Db.Connection.t => unit = "release";
[@bs.send]
external query_:
  (Sihl.Core.Db.Connection.t, string, Js.Json.t) => Async.t(Js.Json.t) =
  "query";
