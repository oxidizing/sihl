let requests_postgresql =
  {|let clean_request =
  Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE {{table_name}} CASCADE;"
;;

let insert_request =
  Caqti_request.exec
    {{caqti_type}}
    {sql|
INSERT INTO {{table_name}} (
  uuid,
  {{fields}},
  created_at,
  updated_at
) VALUES (
  ?::uuid,
  {{parameters}},
  ? AT TIME ZONE 'UTC',
  ? AT TIME ZONE 'UTC'
)
        |sql}
;;

let update_request =
  Caqti_request.exec
    {{caqti_type_update}}
    {sql|
UPDATE {{table_name}} SET
  {{update_fields}},
  updated_at = NOW() AT TIME ZONE 'UTC'
WHERE uuid = $1::uuid;
        |sql}
;;

let find_request =
  Caqti_request.find_opt
    Caqti_type.string
    {{caqti_type}}
    {sql|
SELECT
  uuid,
  {{fields}},
  created_at,
  updated_at
FROM {{table_name}}
WHERE uuid = ?::uuid
        |sql}
;;

let filter_fragment = {sql|
WHERE {{filter_fragment}}
|sql}

let search_query =
  {sql|
SELECT
  COUNT(*) OVER() as total,
  uuid,
  {{fields}},
  created_at,
  updated_at
FROM {{table_name}}
|sql}
;;

let search_request =
  Sihl.Database.prepare_search_request
    ~search_query
    ~filter_fragment
    ~sort_by_field:"id"
    {{caqti_type}}
;;

let delete_request =
  Caqti_request.exec
    Caqti_type.string
    {sql|
DELETE FROM {{table_name}}
WHERE uuid = ?::uuid
        |sql}
;;

|}
;;

let requests_mariadb =
  {|let clean_request =
  Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE {{table_name}};"
;;

let insert_request =
  Caqti_request.exec
    {{caqti_type}}
    {sql|
INSERT INTO {{table_name}} (
  uuid,
  {{fields}},
  created_at,
  updated_at
) VALUES (
  UNHEX(REPLACE(?, '-', '')),
  {{parameters}},
  ?,
  ?
)
        |sql}
;;

let update_request =
  Caqti_request.exec
    {{caqti_type_update}}
    {sql|
UPDATE {{table_name}} SET
  {{update_fields}},
  updated_at = NOW()
WHERE uuid = UNHEX(REPLACE($1, '-', ''));
        |sql}
;;

let find_request =
  Caqti_request.find_opt
    Caqti_type.string
    {{caqti_type}}
    {sql|
SELECT
  LOWER(CONCAT(
    SUBSTR(HEX(uuid), 1, 8), '-',
    SUBSTR(HEX(uuid), 9, 4), '-',
    SUBSTR(HEX(uuid), 13, 4), '-',
    SUBSTR(HEX(uuid), 17, 4), '-',
    SUBSTR(HEX(uuid), 21)
  )),
  {{fields}},
  created_at,
  updated_at
FROM {{table_name}}
WHERE uuid = UNHEX(REPLACE(?, '-', ''))
        |sql}
;;

let filter_fragment = {sql|
WHERE {{filter_fragment}}
|sql}

let search_query =
  {sql|
SELECT
  COUNT(*) OVER() as total,
  LOWER(CONCAT(
    SUBSTR(HEX(uuid), 1, 8), '-',
    SUBSTR(HEX(uuid), 9, 4), '-',
    SUBSTR(HEX(uuid), 13, 4), '-',
    SUBSTR(HEX(uuid), 17, 4), '-',
    SUBSTR(HEX(uuid), 21)
  )),
  {{fields}},
  created_at,
  updated_at
FROM {{table_name}}
|sql}
;;

let count_query = {sql| SELECT COUNT(*) FROM {{table_name}} |sql}

let search_request =
  Sihl.Database.prepare_search_request
    ~search_query
    ~count_query
    ~filter_fragment
    ~sort_by_field:"id"
    {{caqti_type}}
;;

let delete_request =
  Caqti_request.exec
    Caqti_type.string
    {sql|
DELETE FROM {{table_name}}
WHERE uuid = UNHEX(REPLACE(?, '-', ''))
        |sql}
;;
|}
;;

let queries =
  {|

let clean () = Sihl.Database.exec clean_request ()
;;

let insert ({{name}} : Entity.t) =
  Sihl.Database.exec insert_request {{caqti_value}}
;;

let update ({{name}} : Entity.t) =
  Sihl.Database.exec update_request {{caqti_value_update}}
;;

let find (id : string) : Entity.t option Lwt.t =
  let open Lwt.Syntax in
  let* {{name}} = Sihl.Database.find_opt find_request id in
  Lwt.return
  @@ Option.map
       (fun {{destructured_fields}} ->
         Entity.{ id; {{created_value}} created_at; updated_at })
       {{name}}
;;

let search filter sort ~limit ~offset =
  let open Lwt.Syntax in
  let* result =
    Sihl.Database.run_search_request
      search_request
      sort
      filter
     ~limit
     ~offset
  in
  let {{name}}s =
    List.map
      ~f:(fun {{destructured_fields}} ->
        Entity.{ id; {{created_value}} created_at; updated_at })
      (fst result)
  in
  Lwt.return @@ ({{name}}s, snd result)
;;

let delete ({{name}} : Entity.t) : unit Lwt.t =
  Sihl.Database.exec delete_request {{name}}.Entity.id
;;
|}
;;

let caqti_type (schema : Gen_core.schema) =
  let rec loop = function
    | [ el1; el2 ] ->
      let el1 = Gen_core.caqti_type_of_gen_type el1 in
      let el2 = Gen_core.caqti_type_of_gen_type el2 in
      Format.sprintf "(tup2 %s %s)" el1 el2
    | el1 :: rest ->
      let el1 = Gen_core.caqti_type_of_gen_type el1 in
      Format.sprintf "(tup2 %s %s)" el1 (loop rest)
    | [] -> failwith "Empty schema provided"
  in
  let types =
    List.concat
      Gen_core.[ [ String ]; List.map snd schema; [ Datetime; Datetime ] ]
  in
  Format.sprintf "Caqti_type.%s" (loop types)
;;

let caqti_type_update (schema : Gen_core.schema) =
  let rec loop = function
    | [ el1; el2 ] ->
      let el1 = Gen_core.caqti_type_of_gen_type el1 in
      let el2 = Gen_core.caqti_type_of_gen_type el2 in
      Format.sprintf "(tup2 %s %s)" el1 el2
    | el1 :: rest ->
      let el1 = Gen_core.caqti_type_of_gen_type el1 in
      Format.sprintf "(tup2 %s %s)" el1 (loop rest)
    | [] -> failwith "Empty schema provided"
  in
  let types = List.cons Gen_core.String (List.map snd schema) in
  Format.sprintf "Caqti_type.%s" (loop types)
;;

let caqti_value name (schema : Gen_core.schema) =
  let rec loop = function
    | [ el1; el2 ] ->
      let el1 = Format.sprintf "%s.Entity.%s" name el1 in
      let el2 = Format.sprintf "%s.Entity.%s" name el2 in
      Format.sprintf "(%s, %s)" el1 el2
    | el1 :: rest ->
      let el1 = Format.sprintf "%s.Entity.%s" name el1 in
      Format.sprintf "(%s, %s)" el1 (loop rest)
    | [] -> failwith "Empty schema provided"
  in
  let names =
    List.concat
      [ [ "id" ]; List.map fst schema; [ "created_at"; "updated_at" ] ]
  in
  loop names
;;

let caqti_value_update name (schema : Gen_core.schema) =
  let rec loop = function
    | [ el1; el2 ] ->
      let el1 = Format.sprintf "%s.Entity.%s" name el1 in
      let el2 = Format.sprintf "%s.Entity.%s" name el2 in
      Format.sprintf "(%s, %s)" el1 el2
    | el1 :: rest ->
      let el1 = Format.sprintf "%s.Entity.%s" name el1 in
      Format.sprintf "(%s, %s)" el1 (loop rest)
    | [] -> failwith "Empty schema provided"
  in
  let names = List.cons "id" (List.map fst schema) in
  loop names
;;

let destructured_fields (schema : Gen_core.schema) =
  let rec loop = function
    | [ el1; el2 ] -> Format.sprintf "(%s, %s)" el1 el2
    | el1 :: rest -> Format.sprintf "(%s, %s)" el1 (loop rest)
    | [] -> failwith "Empty schema provided"
  in
  let names =
    List.concat
      [ [ "id" ]; List.map fst schema; [ "created_at"; "updated_at" ] ]
  in
  loop names
;;

let fields (schema : Gen_core.schema) =
  schema |> List.map fst |> String.concat ", \n  "
;;

let update_fields (schema : Gen_core.schema) =
  schema
  |> List.mapi (fun idx (name, _) ->
         (* We start with $2 because $1 is the id which is never updated. *)
         Format.sprintf "%s = $%d" name (idx + 2))
  |> String.concat ", \n  "
;;

let parameters (schema : Gen_core.schema) =
  schema |> List.map (fun _ -> "?") |> String.concat ",\n  "
;;

let filter_fragment (schema : Gen_core.schema) =
  let open Gen_core in
  schema
  |> List.filter (fun (_, type_) -> type_ == String)
  |> List.map fst
  |> List.map @@ Format.sprintf "%s LIKE $1"
  |> String.concat " OR "
;;

let file
    (database : Gen_core.database)
    (name : string)
    (schema : Gen_core.schema)
  =
  let open Gen_core in
  let params =
    [ "name", name
    ; "table_name", Format.sprintf "%ss" name
    ; "filter_fragment", filter_fragment schema
    ; "caqti_type", caqti_type schema
    ; "caqti_type_update", caqti_type_update schema
    ; "caqti_value", caqti_value name schema
    ; "caqti_value_update", caqti_value_update name schema
    ; "destructured_fields", destructured_fields schema
    ; "created_value", Gen_entity.created_value schema
    ; "fields", fields schema
    ; "update_fields", update_fields schema
    ; "parameters", parameters schema
    ]
  in
  let template =
    match database with
    | MariaDb -> requests_mariadb ^ queries
    | PostgreSql -> requests_postgresql ^ queries
  in
  Gen_core.{ name = "repo.ml"; template; params }
;;
