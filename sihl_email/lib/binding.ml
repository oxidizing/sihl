module Repository = struct
  module MariaDb : Contract.REPOSITORY = Repository_mariadb

  module Postgres : Contract.REPOSITORY = Repository_postgres

  let key : (module Contract.REPOSITORY) Sihl_core.Registry.Key.t =
    Sihl_core.Registry.Key.create "emails repository"

  let default () =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get key
    in
    [ (module Repository : Sihl_core.Contract.REPOSITORY) ]
end

module Transport = struct
  let key :
      (module Sihl_core.Contract.Email.EMAIL with type email = Model.Email.t)
      Sihl_core.Registry.Key.t =
    Sihl_core.Registry.Key.create "emails transport"
end
