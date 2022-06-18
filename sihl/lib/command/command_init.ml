module Config = Sihl__config.Config
module P = Command_pure
module F = Command_init_files

type template =
  | Dir of string * template list
  | File of (string * string)

let template name db =
  Dir
    ( name
    , [ Dir
          ( "bin"
          , [ File ("dune", F.dune "bin" [ "lib" ]); File ("bin.ml", F.bin) ] )
      ; Dir
          ( "lib"
          , [ File
                ( "dune"
                , F.dune
                    "lib"
                    [ "sihl"
                    ; "form"
                    ; "model"
                    ; "template"
                    ; "view"
                    ; "settings"
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
                , [ File ("dune", F.dune "model" [ "sihl" ])
                  ; File ("model.ml", F.model)
                  ] )
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
            ; Dir
                ( "settings"
                , [ File ("dune", F.dune "settings" [ "sihl" ])
                  ; File ("settings.ml", F.settings)
                  ; File ("config.ml", F.config db)
                  ] )
            ] )
      ; Dir ("static", [ File (".gitkeep", "") ])
      ; Dir ("test", [ File ("dune", F.dune_test db); File ("test.ml", F.test) ])
      ; Dir ("migration", [ File (".gitkeep", "") ])
      ; File (".ocamlformat", F.ocamlformat)
      ; File (".env", "")
      ; File (".gitignore", F.gitignore)
      ; File ("dune-project", F.dune_project)
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

let fn = function
  | name :: args ->
    let path, db =
      match args with
      | path :: "postgresql" :: _ -> path, Config.Postgresql
      | path :: "postgres" :: _ -> path, Config.Postgresql
      | path :: "mariadb" :: _ -> path, Config.Mariadb
      | path :: _ -> path, Config.Postgresql
      | [] -> Sys.getcwd (), Config.Postgresql
    in
    print_endline
    @@ Format.sprintf
         "create sihl project %s at %s"
         name
         (Filename.concat path name);
    write_template path (template name db)
  | _ -> raise P.Invalid_usage
;;

let t : P.t =
  { name = "init"
  ; description = "Creates an empty Sihl project"
  ; usage = "sihl init <project_name> <directory> <postgres|mariadb>"
  ; fn
  }
;;
