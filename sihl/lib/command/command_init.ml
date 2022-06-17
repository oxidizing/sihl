module P = Command_pure
module F = Command_init_files

type template =
  | Dir of string * template list
  | File of (string * string)

let template name =
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
                    [ "sihl"; "form"; "model"; "template"; "view"; "settings" ]
                )
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
                  ; File ("base.ml", F.settings_base)
                  ; File ("local.ml", F.settings_local)
                  ; File ("production.ml", F.settings_production)
                  ; File ("test.ml", F.settings_test)
                  ] )
            ] )
      ; Dir ("static", [ File (".gitkeep", "") ])
      ; Dir ("test", [ File ("dune", F.dune_test); File ("test.ml", F.test) ])
      ; Dir ("migration", [ File (".gitkeep", "") ])
      ; File (".ocamlformat", F.ocamlformat)
      ; File ("dune-project", F.dune_project)
      ] )
;;

let write_file file_name ~content =
  print_endline @@ Format.sprintf "write %s" file_name;
  CCIO.File.write_exn file_name content
;;

let make_dir path = Sys.mkdir path 0o755

let write_template path =
  let rec loop cwd = function
    | Dir (dir_name, files) ->
      let cwd = Filename.concat cwd dir_name in
      make_dir cwd;
      List.iter (loop cwd) files
    | File (file_name, content) ->
      let file_name = Filename.concat cwd file_name in
      write_file file_name ~content
  in
  loop path
;;

let fn = function
  | name :: directory ->
    let path =
      match directory with
      | path :: _ -> path
      | [] -> Sys.getcwd ()
    in
    print_endline
    @@ Format.sprintf
         "create sihl project %s at %s"
         name
         (Filename.concat path name);
    write_template path (template name)
  | _ -> raise P.Invalid_usage
;;

let t : P.t =
  { name = "init"
  ; description = "Creates an empty Sihl project"
  ; usage = "sihl init <project_name> <directory>"
  ; fn
  }
;;
