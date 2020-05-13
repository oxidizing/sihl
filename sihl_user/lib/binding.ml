module Repository = struct
  module MariaDb : Contract.REPOSITORY = Repository_mariadb

  module Postgres : Contract.REPOSITORY = Repository_postgres

  let key : (module Contract.REPOSITORY) Sihl_core.Registry.Key.t =
    Sihl_core.Registry.Key.create "users repository"

  let default () =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get key
    in
    [ (module Repository : Sihl_core.Contract.REPOSITORY) ]
end

let default =
  [
    Sihl_core.Registry.Binding.create Repository.key (module Repository_postgres);
  ]
