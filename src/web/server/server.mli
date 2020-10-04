(** The web server service contains a HTTP server implementation. *)

(** {1 Service Installation}

    Use the provided {!Sihl.Web.Server.MakeOpium} to create a web server service that uses
    {:https://github.com/rgrinberg/opium/}. You need to inject a
    {!Sihl.Log.Service.Sig.SERVICE} and a {!Sihl.Cmd.Service.Sig.SERVICE}. Use the default
    implementation provided by Sihl:

    {[
      module Log = Sihl.Log.Service.Make ()
      module Cmd = Sihl.Cmd.Service.Make ()
      module WebServer = Sihl.Web.Server.Service.Make (Cmd)
    ]} *)

module Service = Server_service

(** {1 Usage}

    {[
      let hello_page =
        Sihl.Web.Route.get "/hello/" (fun _ ->
            Sihl.Web.Res.(html |> set_body "Hello!") |> Lwt.return)

      let hello_api =
        Sihl.Web.Route.get "/hello/" (fun _ ->
            Sihl.Web.Res.(json |> set_body {|{"msg":"Hello!"}|}) |> Lwt.return)

      let endpoints = [ ("/page", [ hello_page ], []); ("/api", [ hello_api ], []) ]

      WebServer.register_endpoints endpoints;
      let* () = WebServer.start_server ctx in
      ...
    ]} *)

type routes = Server_core.routes
type middleware_stack = Server_core.middleware_stack
type endpoint = Server_core.endpoint
