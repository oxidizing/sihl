module Test = Sihl__test.Test
module Model = Sihl__model.Model
module Query = Sihl__query.Query

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

  let t = Model.create to_yojson of_yojson "query_models" Fields.names schema
end

let%test_unit "1 + 1 = 2" =
  let open Test.Assert in
  [%test_result: int] (1 + 1) ~expect:2
;;

let%test_unit "insert sql" =
  let open Test.Assert in
  let a =
    A.make ~int:1 ~bool:true ~string:"bar" ~timestamp:(Ptime_clock.now ())
  in
  let sql = Query.(show (insert A.t a)) in
  [%test_result: string]
    sql
    ~expect:
      "INSERT INTO query_models (int, bool, string, timestamp) VALUES (?, ?, \
       ?, ?) RETURNING id"
;;

let%test_unit "select sql" =
  let open Test.Assert in
  let sql = Query.(show (all A.t |> where_int A.Fields.int eq 4)) in
  [%test_result: string] sql ~expect:"SELECT * FROM query_models WHERE int = ?"
;;

let%test_unit "select nested filters sql" =
  let open Test.Assert in
  let sql =
    Query.(
      show
        (all A.t
        |> where_int A.Fields.int eq 4
        |> or_ [ where_int A.Fields.int gt 1; where_int A.Fields.int lt 10 ]
        |> where_int A.Fields.int eq 50))
  in
  [%test_result: string]
    sql
    ~expect:
      "SELECT * FROM query_models WHERE ((int = ? OR (int > ? AND int < ?)) \
       AND int = ?)"
;;
