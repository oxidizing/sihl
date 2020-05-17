module Repository = struct
  let key : (module Repo_sig.REPOSITORY) Sihl.Core.Registry.Key.t =
    Sihl.Core.Registry.Key.create "users repository"

  let default () =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.get key
    in
    [ (module Repository : Sihl.Core.Contract.REPOSITORY) ]
end
