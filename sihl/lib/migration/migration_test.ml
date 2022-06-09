module A = struct
  type t =
    { int : int
    ; bool : bool
    ; string : string
    ; timestamp : Model.Ptime.t
    }
  [@@deriving yojson, fields, make]

  let schema =
    Model.
      [ int Fields.int
      ; bool Fields.bool
      ; string ~max_length:80 Fields.string
      ; timestamp ~default:Now ~update:true Fields.timestamp
      ]
  ;;

  let t = Model.create to_yojson of_yojson "a_models" Fields.names schema
end

module B = struct
  type variant =
    | Foo
    | Bar
  [@@deriving yojson]

  type t =
    { a_id : int
    ; variant : variant
    }
  [@@deriving yojson, fields, make]

  let schema =
    Model.
      [ foreign_key Cascade "a_models" Fields.a_id
      ; enum variant_of_yojson variant_to_yojson Fields.variant
      ]
  ;;

  let t = Model.create to_yojson of_yojson "b_models" Fields.names schema
end

let%test_unit "create table migrations postgresql" =
  let open Test.Assert in
  let up, _ = Migration.sql ~db:Config.Postgresql () in
  [%test_result: string]
    up
    ~expect:
      "CREATE TABLE IF NOT EXISTS a_models (\n\
      \  id SERIAL PRIMARY KEY,\n\
      \  int INTEGER NOT NULL,\n\
      \  bool BOOLEAN NOT NULL DEFAULT false,\n\
      \  string VARCHAR(80) NOT NULL,\n\
      \  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP\n\
       );\n\n\
       CREATE TABLE IF NOT EXISTS b_models (\n\
      \  id SERIAL PRIMARY KEY,\n\
      \  a_id INTEGER NOT NULL,\n\
      \  variant VARCHAR(255) NOT NULL\n\
       );\n\n\
       ALTER TABLE b_models\n\
      \  ADD CONSTRAINT fk_b_models_a_models FOREIGN KEY (a_id) REFERENCES \
       a_models (id) ON DELETE CASCADE;"
;;

let%test_unit "create table migrations mariadb" =
  let open Test.Assert in
  let up, _ = Migration.sql ~db:Config.Mariadb () in
  [%test_result: string]
    up
    ~expect:
      "CREATE TABLE IF NOT EXISTS a_models (\n\
      \  id MEDIUMINT NOT NULL AUTO_INCREMENT,\n\
      \  int INTEGER NOT NULL,\n\
      \  bool BOOLEAN NOT NULL DEFAULT false,\n\
      \  string VARCHAR(80) NOT NULL,\n\
      \  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE \
       CURRENT_TIMESTAMP\n\
       );\n\n\
       CREATE TABLE IF NOT EXISTS b_models (\n\
      \  id MEDIUMINT NOT NULL AUTO_INCREMENT,\n\
      \  a_id INTEGER NOT NULL,\n\
      \  variant VARCHAR(255) NOT NULL\n\
       );\n\n\
       ALTER TABLE b_models\n\
      \  ADD CONSTRAINT fk_b_models_a_models FOREIGN KEY (a_id) REFERENCES \
       a_models (id) ON DELETE CASCADE;"
;;
