(* This is the entry point to the Sihl app.

   The parts of your app come together here and are wired to the services.
   This is also the central registry for infrastructure services.
 *)

let services =
  [ Sihl.Database.register ()
  {%- if database == 'PostgreSql' %}
  ; Service.Migration.(register ~migrations:Database.Migration.all ())
  {%- endif %}
  {%- if database == 'MariaDb' %}
  ; Service.Migration.(register ~migrations:Database.Migration.all ())
  {%- endif %}
  ; Sihl.Web.Http.register
      ~middlewares:Routes.Global.middlewares
      ~routers:[ Routes.Api.router; Routes.Site.router ] ()
  ]
;;


let () =
  Sihl.App.(
    empty |> with_services services |> run ~commands:[])
;;
