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
      ; string Fields.string
      ; timestamp Fields.timestamp
      ]
  ;;

  let t = Model.create to_yojson of_yojson "a_model" Fields.names schema
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
      [ foreign_key "a_model" Fields.a_id
      ; enum variant_of_yojson variant_to_yojson Fields.variant
      ]
  ;;

  let t = Model.create to_yojson of_yojson "b_model" Fields.names schema
end

let%test_unit "generate create table migrations" =
  let open Test.Assert in
  let sql = Migration_sql.create_tables () in
  [%test_result: string]
    sql
    ~expect:
      {|CREATE TABLE a_models (
  id SERIAL PRIMARY KEY,
  int INTEGER NOT NULL,
  bool BOOLEAN NOT NULL,
  string TEXT NOT NULL,
  timestamp TIMESTAMP NOT NULL
);

CREATE TABLE b_models (
  id SERIAL PRIMARY KEY,
  a_model INTEGER NOT NULL,
  string TEXT NOT NULL,
  FOREIGN KEY (a_model) REFERENCES a_models (id)
);
|}
;;
