let template_mariadb =
  {|let create_{{name}}s_table =
  Sihl.Database.Migration.create_step
    ~label:"create {{name}}s table"
    {sql|
      CREATE TABLE IF NOT EXISTS {{name}}s (
        id BIGINT UNSIGNED AUTO_INCREMENT,
        uuid BINARY(16) NOT NULL,
        {{schema}},
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      CONSTRAINT unique_uuid UNIQUE KEY (uuid)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    |sql}
;;

let migration =
  Sihl.Database.Migration.(
    empty "{{name}}"
    |> add_step create_{{name}}s_table
  )
;;
|}
;;

let template_postgresql =
  {|let create_{{name}}s_table =
  Sihl.Database.Migration.create_step
    ~label:"create {{name}}s table"
    {sql|
      CREATE TABLE IF NOT EXISTS {{name}}s (
        id serial,
        uuid UUID NOT NULL,
        {{schema}},
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE (uuid)
      )
    |sql}
;;

let migration =
  Sihl.Database.Migration.(
    empty "{{name}}"
    |> add_step create_{{name}}s_table
  )
;;
|}
;;

let type_of_gen_type_postgresql (t : Gen_core.gen_type) : string =
  let open Gen_core in
  match t with
  | Float -> "DECIMAL NOT NULL"
  | Int -> "INTEGER NOT NULL"
  | Bool -> "BOOLEAN NOT NULL"
  | String -> "VARCHAR(128) NOT NULL"
  | Datetime -> "TIMESTAMP"
;;

let type_of_gen_type_mariadb (t : Gen_core.gen_type) : string =
  let open Gen_core in
  match t with
  | Float -> "FLOAT NOT NULL"
  | Int -> "INT NOT NULL"
  | Bool -> "BOOLEAN NOT NULL"
  | String -> "VARCHAR(128) NOT NULL"
  | Datetime -> "TIMESTAMP"
;;

let migration_schema_postgresql (schema : Gen_core.schema) =
  schema
  |> List.map (fun (name, type_) ->
    Format.sprintf "%s %s" name (type_of_gen_type_postgresql type_))
  |> String.concat ",\n  "
;;

let migration_schema_mariadb (schema : Gen_core.schema) =
  schema
  |> List.map (fun (name, type_) ->
    Format.sprintf "%s %s" name (type_of_gen_type_mariadb type_))
  |> String.concat ",\n  "
;;

let write_migration_file
      (database : Gen_core.database)
      (name : string)
      (schema : Gen_core.schema)
  =
  let open Gen_core in
  let file =
    match database with
    | PostgreSql ->
      { name = Format.sprintf "%s.ml" name
      ; template = template_postgresql
      ; params = [ "name", name; "schema", migration_schema_postgresql schema ]
      }
    | MariaDb ->
      { name = Format.sprintf "%s.ml" name
      ; template = template_mariadb
      ; params = [ "name", name; "schema", migration_schema_mariadb schema ]
      }
  in
  write_in_database file
;;
