module Repository = struct
  let key : (module Repo_sig.REPOSITORY) Sihl.Core.Registry.Key.t =
    Sihl.Core.Registry.Key.create "emails repository"

  let default () =
    let (module Repository : Repo_sig.REPOSITORY) =
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
