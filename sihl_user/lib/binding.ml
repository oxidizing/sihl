module Repository = struct
  module MariaDb : Contract.REPOSITORY = Repository_mariadb

  module Postgres : Contract.REPOSITORY = Repository_postgres

  let key : (module Contract.REPOSITORY) Sihl.Registry.Key.t =
    Sihl.Registry.Key.create "users repository"

  let default () =
    let (module Repository : Contract.REPOSITORY) = Sihl.Registry.get key in
    [ (module Repository : Sihl.Contract.REPOSITORY) ]
end

let default =
  [ Sihl.Registry.Binding.create Repository.key (module Repository_postgres) ]
