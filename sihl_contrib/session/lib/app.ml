let name = "Session App"

let namespace = "sessions"

let config () = []

let endpoints () = []

let repos () = Bind.Repository.default ()

let bindings () =
  [ Sihl.Core.Registry.bind Sihl.Http.Session.key (module Service) ]

let commands () = []

let start () = Ok ()

let stop () = Ok ()
