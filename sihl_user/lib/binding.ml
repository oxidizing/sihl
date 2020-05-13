module Repository = struct
  let key : (module Contract.REPOSITORY) Sihl_core.Registry.Key.t =
    Sihl_core.Registry.Key.create "users repository"

  let default () =
    let (module Repository : Contract.REPOSITORY) =
      Sihl_core.Registry.get key
    in
    [ (module Repository : Sihl_core.Contract.REPOSITORY) ]
end
