module Repository = struct
  let key : (module Repo.REPOSITORY) Sihl.Core.Container.Key.t =
    Sihl.Core.Container.Key.create "session.repository"

  let default () =
    let (module Repository : Repo.REPOSITORY) =
      Sihl.Core.Container.fetch_exn key
    in
    [ (module Repository : Sihl.Sig.REPO) ]
end
