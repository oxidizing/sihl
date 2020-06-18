module Repository = struct
  let key : (module Repo_sig.REPOSITORY) Sihl.Core.Registry.Key.t =
    Sihl.Core.Registry.Key.create "email.repository"

  let default () =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Registry.fetch_exn key
    in
    [ (module Repository : Sihl.Sig.REPO) ]
end

module Transport = struct
  let key : (module Sihl.Email.SERVICE) Sihl.Core.Registry.Key.t =
    Sihl.Core.Registry.Key.create "email.transport"
end
