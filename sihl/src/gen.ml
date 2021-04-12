let service =
  Core_command.make
    ~name:"gen.service"
    ~help:
      "<database> <service name> <name>:<type> <name>:<type> <name>:<type> ... \n\
       Supported types are: int | float | bool | string | datetime \n\
       Supported databases are: mariadb | postgresql"
    ~description:"Generates a service, tests and migrations."
    (function
      | database :: service_name :: schema ->
        (match Gen_core.schema_of_string schema with
        | Ok schema ->
          Gen_service.generate database service_name schema;
          Lwt.return @@ Some ()
        | Error msg ->
          print_endline msg;
          raise @@ Core_command.Exception "")
      | _ -> Lwt.return None)
;;

let view =
  Core_command.make
    ~name:"gen.view"
    ~help:
      "<service name> <name>:<type> <name>:<type> <name>:<type> ... \n\
       Supported types are: int, float, bool, string, datetime"
    ~description:
      "Generates an HTML view that contains a form to create and update a \
       resource."
    (function
      | name :: schema ->
        (match Gen_core.schema_of_string schema with
        | Ok schema ->
          Gen_view.generate name schema;
          Lwt.return @@ Some ()
        | Error msg ->
          print_endline msg;
          raise @@ Core_command.Exception "")
      | [] -> Lwt.return None)
;;

let html_help service_name module_name =
  Format.sprintf
    {|
Resource '%ss' created. To finalize the generation:

1.) Copy this route

    let %s =
      Sihl.Web.choose
        ~middlewares:
          [ Sihl.Web.Middleware.csrf ()
          ; Sihl.Web.Middleware.flash ()
          ]
        (Rest.resource
          "%ss"
          %s.schema
          (module %s : Rest.SERVICE with type t = %s.t)
          (module View_%s : Rest.VIEW with type t = %s.t))
    ;;

into your `routes/routes.ml` and mount it with the HTTP service. Don't forget to add '%s' and 'view_%s' to `routes/dune`.

2.) Add the migration

    Database.%s.all

to the list of migrations before running `sihl migrate`.

3.) You should also run `make format` to apply your styling rules.

4.) Visit http://localhost:3000/%ss
|}
    service_name
    service_name
    service_name
    module_name
    module_name
    module_name
    service_name
    module_name
    service_name
    service_name
    module_name
    service_name
;;

let html =
  Core_command.make
    ~name:"gen.html"
    ~help:
      "<database> <service name> <name>:<type> <name>:<type> <name>:<type> ... \n\
       Supported types are: int, float, bool, string, datetime \n\
       Supported databases are: mariadb | postgresql"
    ~description:
      "Generates a controller, HTML views, a service, tests and migrations for \
       an HTML resource. This generator is a combination of gen.service and \
       gen.view."
    (function
      | database :: service_name :: schema ->
        (match Gen_core.schema_of_string schema with
        | Ok schema ->
          let module_name = String.capitalize_ascii service_name in
          Gen_service.generate database service_name schema;
          Gen_view.generate service_name schema;
          print_endline @@ html_help service_name module_name;
          Lwt.return @@ Some ()
        | Error msg ->
          print_endline msg;
          raise @@ Core_command.Exception "")
      | _ -> Lwt.return None)
;;

let commands = [ service; view; html ]
