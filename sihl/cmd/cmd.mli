(** Use this module to create your own command line commands in order to interact with the Sihl app.

Services can register command with the command service. This is why a lot of services have a dependency on it. All the built-in commands are contributed by individual services using this mechanism.
Examples for those commands are:

- [migrate] is registered by the migration service and it runs the migrations
- [start] is registered by the web server service and it starts the web server
- [createadmin] is registered by the user service and it creates an admin user, useful to bootstrap your app so you have one user to log in

You can contribute your custom commands the same way to interact with your app through the CLI. This can be very handy for development and administration. You sometimes want to call services without going through the HTTP stack, authentication, validation and authorization layers.
*)

type fn = Base.string Base.list -> Base.unit Lwt.t

val pp_fn :
  Ppx_deriving_runtime.Format.formatter -> fn -> Ppx_deriving_runtime.unit

val show_fn : fn -> Ppx_deriving_runtime.string

exception Invalid_usage of Base.string

type t = Cmd_core.t

val pp : Ppx_deriving_runtime.Format.formatter -> t -> Ppx_deriving_runtime.unit

val make :
  name:Base.string ->
  ?help:Base.string ->
  description:Base.string ->
  fn:fn ->
  unit ->
  t

val fn : t -> fn

val description : t -> Base.string

val help : t -> Base.string Base.option

val name : t -> Base.string

val show : t -> string

module Service = Cmd_service
(** {1 Installation}

[module Cmd = Sihl.Cmd.Service.Make ()]

*)

(** {1 Usage}

This is how the command [createadmin] is implemented:

{[
  let create_admin_cmd =
    Cmd.make ~name:"createadmin" ~help:"<username> <email> <password>"
      ~description:"Create an admin user"
      ~fn:(fun args ->
        match args with
        | [ username; email; password ] ->
            let ctx = Core.Ctx.empty |> DbService.add_pool in
            User_service.create_admin ctx ~email ~password ~username:(Some username)
            |> Lwt_result.map ignore
        | _ -> Lwt_result.fail "Usage: <username> <email> <password>")
      ()

  let _ =
    App.(empty
    |> with_services services
    |> with_commands [ create_admin_cmd ]
    |> run)
]}
*)
