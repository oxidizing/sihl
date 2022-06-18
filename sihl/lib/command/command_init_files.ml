module Config = Sihl__config.Config

let dune ?(ppx = []) name libs =
  let libs = String.concat " " libs in
  let ppx =
    if List.length ppx > 0
    then ppx |> String.concat " " |> Format.sprintf "\n (preprocess (pps %s))"
    else ""
  in
  Format.sprintf
    {|(library
     (name %s)
     (libraries %s)%s)|}
    name
    libs
    ppx
;;

let dune_test db =
  let caqti_driver =
    match db with
    | Config.Postgresql -> "caqti-driver-postgresql"
    | Config.Mariadb -> "caqti-driver-mariadb"
  in
  Format.sprintf
    {|(library
   (name test)
   (libraries sihl lib %s)
   (inline_tests)
   (preprocess (pps ppx_inline_test ppx_assert lwt_ppx tyxml-jsx)))|}
    caqti_driver
;;

let bin = {|let () = Lib.run ()|}

let lib =
  {|module Config = (val !Settings.config : Settings.S)

   let run () =
  Sihl.run (module Config)
  @@ Dream.serve ~interface:"0.0.0.0"
;;|}
;;

let form =
  "(* Place your form here to process user input. Consult Sihl.Form for more \
   info. *)"
;;

let model =
  "(* Place your models here to describe business models. Consult Sihl.Model \
   for more info. *)"
;;

let template =
  "/* Place your templates here to render HTML and JSON. Consult the TyXML and \
   Yojson documentations for more info. */"
;;

let view =
  "(* Place your views here to act on user input through HTTP requests. \
   Consult Sihl.View for more info. *)"
;;

let config db =
  let database_url =
    match db with
    | Config.Postgresql -> "postgresql://admin:password@127.0.0.1:5432/dev"
    | Config.Mariadb -> "mariadb://admin:password@127.0.0.1:3306/dev"
  in
  Format.sprintf
    {|module Base () = struct
  let database_url = "%s"
  let middlewares = [ Dream.sql_pool database_url; Dream.logger ]
  let debug = Sihl.Config.bool ~default:true "SIHL_DEBUG"
  let test = Sihl.Config.bool ~default:false "SIHL_TEST"

  let sihl_secret =
    "local_%s"
  ;;

  let login_url = "/login"
end

module Local () = struct
  include Base ()
end

module Test () = struct
  include Base ()

  let debug = Sihl.Config.bool ~default:true "SIHL_DEBUG"
  let test = Sihl.Config.bool ~default:true "SIHL_TEST"
end

module Production () = struct
  include Base ()

  let database_url = Sys.getenv "DATABASE_URL"
  let debug = false
  let test = false
  let sihl_secret = Sys.getenv "SIHL_SECRET"
end|}
    (Dream.random 64 |> Base64.encode_string ~alphabet:Base64.uri_safe_alphabet)
    database_url
;;

let settings =
  {|module type S = sig
  include module type of Config.Production ()
end

let config = ref (module Config.Local () : S)

let () =
  match
    ( Sihl.Config.bool ~default:true "SIHL_DEBUG"
    , Sihl.Config.bool ~default:false "SIHL_TEST" )
  with
  | true, false | true, true ->
    print_endline "load configuration for env: local";
    config := (module Config.Local ())
  | false, true ->
    print_endline "load configuration for env: test";
    config := (module Config.Test ())
  | false, false ->
    print_endline "load configuration for env: production";
    config := (module Config.Production ())
;;|}
;;

let test =
  {|let%test_unit "1 + 1 = 2" =
  let open Sihl.Test.Assert in
  [%test_result: int] (1 + 1) ~expect:2
;;|}
;;

let ocamlformat =
  "profile = janestreet\n\
   parse-docstrings = true\n\
   wrap-comments = true\n\
   margin = 80"
;;

let dune_project =
  {|(lang dune 2.8)
(generate_opam_files true)
(package
 (name app)
 (synopsis "A synposis")
 (description
  "Description of this awesome package")
 (depends
  (sihl (>= 4.0.0))
  (tyxml-jsx (>= 4.5.0))
  (caqti-driver-postgresql (>= 1.8.0))
  (caqti-driver-mariadb (>= 1.8.0))))|}
;;

let gitignore = {|/_build/
/_opam/
.merlin
.devcontainer/data|}
