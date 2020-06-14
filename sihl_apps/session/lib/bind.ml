module Repository = struct
  let key : (module Repo.REPOSITORY) Sihl.Core.Registry.Key.t =
    Sihl.Core.Registry.Key.create "session.repository"

  let default () =
    let (module Repository : Repo.REPOSITORY) = Sihl.Core.Registry.get key in
    [ (module Repository : Sihl.Core.Contract.REPOSITORY) ]
end
