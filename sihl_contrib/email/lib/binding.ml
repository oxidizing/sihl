module Repository = struct
  module MariaDb : Contract.REPOSITORY = Repository_mariadb

  module Postgres : Contract.REPOSITORY = Repository_postgres

  let key : (module Contract.REPOSITORY) Sihl.Core.Registry.Key.t =
    Sihl.Core.Registry.Key.create "emails repository"

  let default () =
    let (module Repository : Contract.REPOSITORY) =
      Sihl.Core.Registry.get key
    in
    [ (module Repository : Sihl.Core.Contract.REPOSITORY) ]
end

module Transport = struct
  let key :
      (module Sihl.Core.Contract.Email.EMAIL with type email = Model.Email.t)
      Sihl.Core.Registry.Key.t =
    Sihl.Core.Registry.Key.create "emails transport"
end
