let service =
  Core_command.make
    ~name:"gen.model"
    ~help:
      "<database> <service name> <name>:<type> <name>:<type> <name>:<type> ... \n\
       Supported types are: int | float | bool | string | datetime \n\
       Supported databases are: mariadb | postgresql"
    ~description:
      "Generates a model consisting of a service, an entityt, a repository, \
       tests and migrations."
    (function
      | database :: model_name :: schema ->
        (match Gen_core.schema_of_string schema with
        | Ok schema ->
          Gen_model.generate database model_name schema;
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
      "<model name> <name>:<type> <name>:<type> <name>:<type> ... \n\
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

let html_help model_name module_name =
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
        Sihl.Web.Rest.(
          resource_of_service
            "%ss"
            %s.schema
            ~view:(module View_%s : VIEW with type t = %s.t)
            (module %s : SERVICE with type t = %s.t))
    ;;

into your `routes/routes.ml` and mount it with the HTTP service. Don't forget to add '%s' and 'view_%s' to `routes/dune`.

2.) Add the migration

    Database.%s.migration

to the list of migrations before running `sihl migrate`.

3.) You should also run `make format` to apply your styling rules.

4.) Visit http://localhost:3000/%ss
|}
    model_name
    model_name
    model_name
    module_name
    model_name
    module_name
    module_name
    module_name
    model_name
    model_name
    module_name
    model_name
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
      | database :: model_name :: schema ->
        (match Gen_core.schema_of_string schema with
        | Ok schema ->
          let module_name = String.capitalize_ascii model_name in
          Gen_model.generate database model_name schema;
          Gen_view.generate model_name schema;
          print_endline @@ html_help model_name module_name;
          Lwt.return @@ Some ()
        | Error msg ->
          print_endline msg;
          raise @@ Core_command.Exception "")
      | _ -> Lwt.return None)
;;

let commands = [ service; view; html ]
