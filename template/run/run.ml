(* Register all your infrastructure services here. *)
let services =
  [ Sihl.Database.register ()
  ; Sihl.Schedule.register [ Schedule.hello ]
  ; Service.Migration.(register ~migrations:Database.Migration.all ())
  ; Sihl.Web.Http.register ~middlewares:Routes.global_middlewares Routes.router
  ]
;;

(* This is the entry point of your Sihl app *)
let () =
  Sihl.App.(
    empty |> with_services services |> run ~commands:[ Command.multiply ])
;;
