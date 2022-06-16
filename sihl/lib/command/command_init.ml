module P = Command_pure

type template =
  | Dir of string * template list
  | File of (string * string)

let template name =
  Dir
    ( name
    , [ Dir ("bin", [ File ("dune", "todo"); File ("bin.ml", "todo") ])
      ; Dir
          ( "lib"
          , [ File ("dune", "todo")
            ; File ("lib.ml", "todo")
            ; Dir ("form", [ File ("dune", ""); File ("form.ml", "") ])
            ; Dir ("model", [ File ("dune", ""); File ("model.ml", "") ])
            ; Dir ("template", [ File ("dune", ""); File ("template.ml", "") ])
            ; Dir ("view", [ File ("dune", ""); File ("view.ml", "") ])
            ; Dir
                ( "settings"
                , [ File ("base.ml", "")
                  ; File ("local.ml", "")
                  ; File ("production.ml", "")
                  ; File ("test.ml", "")
                  ; File ("settings.ml", "")
                  ] )
            ] )
      ; Dir ("static", [ File (".gitkeep", "") ])
      ; Dir ("test", [ File ("dune", ""); File ("test.ml", "") ])
      ; Dir ("migration", [ File (".gitkeep", "") ])
      ] )
;;

let write_file file_name ~content =
  print_endline @@ Format.sprintf "write file %s" file_name;
  CCIO.File.write_exn file_name content
;;

let make_dir path =
  print_endline @@ Format.sprintf "make directory %s" path;
  Sys.mkdir path 0o755
;;

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
