module App = Sihl_core.App

(* Core services & Utils *)
module Configuration = Sihl_core.Configuration
module Command = Sihl_core.Command
module Log = Sihl_core.Log
module Time = Sihl_core.Time

(* Cleaner module *)
module Cleaner = struct
  include Sihl_core.Cleaner
end

(* Web module *)
module Web = struct
  include Sihl_web

  let register routers = Sihl_web.Http.register ~routers ()
end

(* Database module *)
module Database = struct
  include Sihl_persistence.Database

  (* Migration module *)
  module Migration = struct
    include Sihl_persistence.Migration

    module Implementation = struct
      let postgresql =
        (module Sihl_persistence.Migration.PostgreSql
        : Sihl_contract.Migration.Sig)
      ;;

      let mariadb =
        (module Sihl_persistence.Migration.MariaDb : Sihl_contract.Migration.Sig)
      ;;
    end
  end
end
