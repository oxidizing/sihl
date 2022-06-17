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

let dune_test =
  {|(library
   (name test)
   (libraries sihl lib)
   (inline_tests)
   (preprocess (pps ppx_inline_test ppx_assert lwt_ppx tyxml-jsx)))|}
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

let settings =
  {|module type S = sig
  include module type of Production
end

let config = ref (module Local: S)

let () = match Sys.getenv "DEBUG", Sys.getenv "TEST" with
  | "true", "false" -> config := (module Local)
  | "false", "true" -> config := (module Test)
  | _ -> config := (module Production)
|}
;;

let settings_base =
  {|let database_url = "postgresql://admin:password@127.0.0.1:5432/dev"
let middlewares = [Dream.sql_pool database_url; Dream.logger]

let debug = Sihl.Config.bool "SIHL_DEBUG"
let test = Sihl.Config.bool "SIHL_TEST"
let sihl_secret = "local_SBw74Pe8hYPReC57e9Ag8xd36y6R9yxhFX6MqE66XPxoAiTsyfayF3q5EfbWXbbV"
let email_default_subject = "Hello there 👋"
let login_url = "/login"|}
;;

let settings_local =
  {|include Base
let debug = Sihl.Config.bool ~default:true "SIHL_DEBUG"
let test = Sihl.Config.bool ~default:false "SIHL_TEST"|}
;;

let settings_test =
  {|include Base
let debug = Sihl.Config.bool ~default:true "SIHL_DEBUG"
let test = Sihl.Config.bool ~default:false "SIHL_TEST"|}
;;

let settings_production =
  {|include Base
let database_url = Sihl.Config.string "DATABASE_URL"
let debug = false
let test = false
let sihl_secret = Sihl.Config.string "SIHL_SECRET"|}
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
