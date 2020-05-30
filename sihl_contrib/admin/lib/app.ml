let name = "Admin App"

let namespace = "admin"

let config () = []

let endpoints () =
  let open Handler in
  [ Dashboard.handler ]

let repos () = []

let bindings () =
  [
    Sihl.Core.Registry.Binding.create Sihl.Admin.Bind.registry_key
      (module Service);
  ]

let commands () = []

let start () = Ok ()

let stop () = Ok ()
