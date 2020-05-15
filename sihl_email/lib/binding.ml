module Repository = struct
  module MariaDb : Contract.REPOSITORY = Repository_mariadb

  module Postgres : Contract.REPOSITORY = Repository_postgres

  let key : (module Contract.REPOSITORY) Sihl.Registry.Key.t =
    Sihl.Registry.Key.create "emails repository"

  let default () =
    let (module Repository : Contract.REPOSITORY) = Sihl.Registry.get key in
    [ (module Repository : Sihl.Contract.REPOSITORY) ]
end

module Transport = struct
  let key :
      (module Sihl.Contract.Email.EMAIL with type email = Model.Email.t)
      Sihl.Registry.Key.t =
    Sihl.Registry.Key.create "emails transport"
end
