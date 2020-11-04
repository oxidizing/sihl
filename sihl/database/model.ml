type pool = (Caqti_lwt.connection, Caqti_error.t) Caqti_lwt.Pool.t
type connection = (module Caqti_lwt.CONNECTION)

let prepare_requests search_query filter_fragment sort_field output_type =
  let asc_request =
    let input_type = Caqti_type.int in
    let query =
      Printf.sprintf "%s ORDER BY %s ASC %s" search_query sort_field "LIMIT $1"
    in
    Caqti_request.collect input_type output_type query
  in
  let desc_request =
    let input_type = Caqti_type.int in
    let query =
      Printf.sprintf "%s ORDER BY %s DESC %s" search_query sort_field "LIMIT $1"
    in
    Caqti_request.collect input_type output_type query
  in
  let filter_asc_request =
    let input_type = Caqti_type.(tup2 string int) in
    let query =
      Printf.sprintf
        "%s %s ORDER BY %s ASC %s"
        search_query
        filter_fragment
        sort_field
        "LIMIT $2"
    in
    Caqti_request.collect input_type output_type query
  in
  let filter_desc_request =
    let input_type = Caqti_type.(tup2 string int) in
    let query =
      Printf.sprintf
        "%s %s ORDER BY %s DESC %s"
        search_query
        filter_fragment
        sort_field
        "LIMIT $2"
    in
    Caqti_request.collect input_type output_type query
  in
  asc_request, desc_request, filter_asc_request, filter_desc_request
;;

let run_request connection requests sort filter limit =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  let r1, r2, r3, r4 = requests in
  let result =
    match sort, filter with
    | `Asc, None -> Connection.collect_list r1 limit
    | `Desc, None -> Connection.collect_list r2 limit
    | `Asc, Some filter -> Connection.collect_list r3 (filter, limit)
    | `Desc, Some filter -> Connection.collect_list r4 (filter, limit)
  in
  result
  |> Lwt.map (Result.map_error Caqti_error.show)
  |> Lwt.map (Result.map_error failwith)
  |> Lwt.map Result.get_ok
;;
