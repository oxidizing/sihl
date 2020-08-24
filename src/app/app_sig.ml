module type KERNEL = sig
  module Random : Utils.Random.Sig.SERVICE

  module Log : Log.Sig.SERVICE

  module Config : Config.Sig.SERVICE

  module Db : Data.Db.Sig.SERVICE

  module Migration : Data.Migration.Sig.SERVICE

  module WebServer : Web.Server.Sig.SERVICE

  module Cmd : Cmd.Sig.SERVICE

  module Schedule : Schedule.Sig.SERVICE
end
