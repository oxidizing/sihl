module Repository = struct
  let key : (module Repo_sig.REPOSITORY) Sihl.Core.Container.Key.t =
    Sihl.Core.Container.Key.create "email.repository"

  let default () =
    let (module Repository : Repo_sig.REPOSITORY) =
      Sihl.Core.Container.fetch_exn key
    in
    [ (module Repository : Sihl.Sig.REPO) ]
end

module Transport = struct
  let key : (module Sihl.Email.Service.SERVICE) Sihl.Core.Container.Key.t =
    Sihl.Core.Container.Key.create "email.transport"
end
