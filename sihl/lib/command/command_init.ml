open Command_pure
module Config = Sihl__config.Config
module F = Command_init_files

type template =
  | Dir of string * template list
  | File of (string * string)

let template name db =
  Dir
    ( name
    , [ Dir
          ( "bin"
          , [ File ("dune", F.dune ~typ:"executable" "bin" [ "lib" ])
            ; File ("bin.ml", F.bin)
            ] )
      ; Dir
          ( "lib"
          , [ File
                ( "dune"
                , F.dune
                    "lib"
                    [ "sihl"
                    ; "dream-livereload"
                    ; "form"
                    ; "model"
                    ; "template"
                    ; "view"
                    ; (match db with
                      | Config.Postgresql -> "caqti-driver-postgresql"
                      | Config.Mariadb -> "caqti-driver-mariadb")
                    ] )
            ; File ("lib.ml", F.lib)
            ; Dir
                ( "form"
                , [ File ("dune", F.dune "form" [ "sihl"; "model" ])
                  ; File ("form.ml", F.form)
                  ] )
            ; Dir
                ( "model"
                , [ File ("dune", F.dune_model); File ("model.ml", F.model) ] )
            ; Dir
                ( "template"
                , [ File
                      ( "dune"
                      , F.dune
                          ~ppx:[ "tyxml-jsx" ]
                          "template"
                          [ "sihl"; "model"; "tyxml" ] )
                  ; File ("template.re", F.template)
                  ] )
            ; Dir
                ( "view"
                , [ File
                      ( "dune"
                      , F.dune "view" [ "sihl"; "model"; "form"; "template" ] )
                  ; File ("view.ml", F.view)
                  ] )
            ] )
      ; Dir ("static", [ File (".gitkeep", "") ])
      ; Dir ("test", [ File ("dune", F.dune_test db); File ("test.ml", F.test) ])
      ; Dir ("migrations", [ File (".gitkeep", "") ])
      ; File (".ocamlformat", F.ocamlformat)
      ; File (".env.base", F.env_base db)
      ; File (".env.local", F.env_local)
      ; File (".env.test", F.env_test)
      ; File (".env.production", F.env_production)
      ; File (".gitignore", F.gitignore)
      ; File ("dune-project", F.dune_project db)
      ; File ("app.opam", F.opam db)
      ; File ("default.nix", F.default_nix db)
      ] )
;;

let write_file file_name ~content =
  print_endline @@ Format.sprintf "write %s" file_name;
  CCIO.File.write_exn file_name content
;;

let make_dir path = Sys.mkdir path 0o755

let write_template path template =
  let rec loop cwd = function
    | Dir (dir_name, files) ->
      let cwd = Filename.concat cwd dir_name in
      make_dir cwd;
      List.iter (loop cwd) files
    | File (file_name, content) ->
      let file_name = Filename.concat cwd file_name in
      write_file file_name ~content
  in
  loop path template
;;

let print_next_steps path =
  print_endline @@ Format.sprintf "Sihl project initialized at %s" path;
  print_endline
    {|Install dependencies in a local switch by running
  opam switch create . 4.14.0 -y

Install recommended dev tools
  opam install ocamlformat-rpc ocaml-lsp-server

Start the development server with
  sihl dev|}
;;

let fn args =
  let module M = Minicli.CLI in
  match args with
  | name :: args ->
    let path =
      M.get_string_opt [ "-d"; "--dir" ] args
      |> Option.value ~default:(Sys.getcwd ())
    in
    let db = M.get_string_opt [ "-b"; "--database" ] args in
    let db =
      match db with
      | Some "postgresql" | Some "postgres" | Some "p" -> Config.Postgresql
      | Some "mariadb" | Some "m" -> Config.Mariadb
      | _ -> Config.Postgresql
    in
    M.finalize ();
    print_endline
    @@ Format.sprintf
         "create sihl project %s at %s"
         name
         (Filename.concat path name);
    write_template path (template name db);
    print_next_steps (Filename.concat path name)
  | _ -> raise Invalid_usage
;;

let t : t =
  { name = "init"
  ; description = "Initializes an empty Sihl project"
  ; usage = "sihl init <project_name> -d <directory> -b <postgres|mariadb>"
  ; fn
  ; stateful = false
  }
;;
