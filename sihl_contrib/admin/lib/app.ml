let name = "Admin App"

let namespace = "admin"

let config () = []

let endpoints () =
  let open Handler in
  [ Catch.handler; Dashboard.handler ]

let repos () = []

let bindings () =
  [
    Sihl.Core.Container.create_binding Sihl.Admin.Bind.registry_key
      (module Service)
      (module Service);
  ]

let commands () = []

let start () = Ok ()

let stop () = Ok ()
