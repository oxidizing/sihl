let name = "Session App"

let namespace = "session"

let config () = []

let endpoints () = []

let repos () = Bind.Repository.default ()

let bindings () =
  [ Sihl.Core.Container.bind Sihl.Http.Session.key (module Service) ]

let commands () = []

let start () = Ok ()

let stop () = Ok ()
