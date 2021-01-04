let cleaners = [ Pizza.cleaner ]

let services =
  [ Sihl.Cleaner.Setup.register cleaners
  ; Sihl.Migration.Setup.(register ~migrations:Database.Migration.all postgresql)
  ; Sihl.Web.Setup.register Http.Route.all
  ]
;;

let commands = [ Command.Create_pizza.run ]
let () = Sihl.App.(empty |> with_services services |> run ~commands)
