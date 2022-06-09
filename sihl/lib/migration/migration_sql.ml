let field_to_sql
    (db : Config.database)
    (model : Model.generic)
    (field : Model.any_field)
    : string * string list
  =
  let open Model in
  (* TODO create primary index stmt using ALTER TABLE *)
  match db, field with
  | _, AnyField (name, ({ nullable; _ }, Integer { default })) ->
    ( Format.sprintf
        "%s INTEGER%s%s"
        name
        (if nullable then " NULL" else " NOT NULL")
        (default
        |> Option.map string_of_int
        |> Option.map (fun s -> " DEFAULT " ^ s)
        |> Option.value ~default:"")
    , [] )
  | _, AnyField (name, ({ nullable; _ }, Boolean { default })) ->
    ( Format.sprintf
        "%s BOOLEAN%s%s"
        name
        (if nullable then " NULL" else " NOT NULL")
        (" DEFAULT " ^ string_of_bool default)
    , [] )
  | _, AnyField (name, ({ nullable; _ }, Email { default })) ->
    ( Format.sprintf
        "%s VARCHAR(255)%s%s"
        name
        (if nullable then " NULL" else " NOT NULL")
        (default
        |> Option.map (fun s -> " DEFAULT " ^ s)
        |> Option.value ~default:"")
    , [] )
  | _, AnyField (name, ({ nullable; _ }, String { max_length; default })) ->
    ( Format.sprintf
        "%s VARCHAR(%s)%s%s"
        name
        (max_length |> Option.map string_of_int |> Option.value ~default:"255")
        (if nullable then " NULL" else " NOT NULL")
        (default
        |> Option.map (fun s -> " DEFAULT " ^ s)
        |> Option.value ~default:"")
    , [] )
  | _, AnyField (name, ({ nullable; _ }, Timestamp { default; update })) ->
    ( Format.sprintf
        "%s TIMESTAMP%s%s%s"
        name
        (if nullable then " NULL" else " NOT NULL")
        (match default with
        | Some Model.Now -> " DEFAULT CURRENT_TIMESTAMP"
        | _ -> "")
        (match db, update with
        | Mariadb, true -> " ON UPDATE CURRENT_TIMESTAMP"
        | _ -> "")
    , []
      (* TODO should we just take a on_update fn hook and call it in ocaml? *)
      (* (match db, update with *)
      (*       | Postgresql, true -> *)
      (*         [ Format.sprintf *)
      (* {|CREATE OR REPLACE FUNCTION update_%s_column() *) (* RETURNS TRIGGER
         AS $$ *) (* BEGIN *) (* NEW.%s = now(); *) (* RETURN NEW; *) (* END; *)
         (* $$ language 'plpgsql';|} *)
      (*             name *)
      (*             name *)
      (*         ; Format.sprintf *)
      (* "CREATE TRIGGER update_%s_%s BEFORE UPDATE ON %s FOR EACH ROW \ *) (*
         EXECUTE PROCEDURE update_%s_column();" *)
      (*             model.name *)
      (*             name *)
      (*             model.name *)
      (*             name *)
      (*         ] *)
      (*       | _ -> []) *) )
  | _, AnyField (name, ({ nullable; _ }, Foreign_key { model_name; on_delete }))
    ->
    ( Format.sprintf
        "%s INTEGER%s"
        name
        (if nullable then " NULL" else " NOT NULL")
    , [ Format.sprintf
          {|ALTER TABLE %s
  ADD CONSTRAINT fk_%s_%s FOREIGN KEY (%s) REFERENCES %s (id) ON DELETE %s;|}
          model.name
          model.name
          model_name
          name
          model_name
          (match on_delete with
          | Cascade -> "CASCADE"
          | Set_null -> "SET NULL"
          | Set_default -> "SET DEFAULT")
      ] )
  | _, AnyField (name, ({ nullable; _ }, Enum { default; to_yojson; _ })) ->
    ( Format.sprintf
        "%s VARCHAR(255)%s%s"
        name
        (if nullable then " NULL" else " NOT NULL")
        (default
        |> Option.map to_yojson
        |> Option.map Yojson.Safe.to_string
        |> Option.value ~default:"")
    , [] )
;;

let model_to_create_table (db : Config.database) (model : Model.generic)
    : string * string list
  =
  let stmts = List.map (field_to_sql db model) model.fields in
  let stmts =
    List.cons
      (match db, model.pk with
      | Postgresql, Serial n -> Format.sprintf "%s SERIAL PRIMARY KEY" n, []
      | Mariadb, Serial n ->
        Format.sprintf "%s MEDIUMINT NOT NULL AUTO_INCREMENT" n, []
      | Sqlite, _ -> failwith "todo sqlite", [])
      stmts
  in
  let create_table_stmt =
    stmts
    |> List.map fst
    |> String.concat ",\n  "
    |> Format.sprintf "CREATE TABLE IF NOT EXISTS %s (\n  %s\n);" model.name
  in
  let other_stmts = stmts |> List.map snd |> List.concat in
  create_table_stmt, other_stmts
;;

let models_to_create_tables (db : Config.database) (models : Model.generic list)
    : string list
  =
  let create_table_stmts =
    models |> List.map @@ model_to_create_table db |> List.map fst
  in
  (* Adding indexes only possible once tables have been created *)
  let other_stmts =
    models
    |> List.map @@ model_to_create_table db
    |> List.map snd
    |> List.concat
  in
  List.concat [ create_table_stmts; other_stmts ]
;;

let sql ?(db = Config.database ()) () : string * string =
  let models = Model.models |> Hashtbl.to_seq |> Seq.map snd |> List.of_seq in
  let stmts = models_to_create_tables db models in
  let up = String.concat "\n\n" stmts in
  (* TODO implement down migrations *)
  up, "todo"
;;
