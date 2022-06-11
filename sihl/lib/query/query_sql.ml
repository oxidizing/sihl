module P = Query_pure

module Dynparam = struct
  type t = Pack : 'a Caqti_type.t * 'a -> t

  let empty = Pack (Caqti_type.unit, ())
  let add t x (Pack (t', x')) = Pack (Caqti_type.tup2 t' t, (x', x))

  let instance (model : 'a Model.t) (Pack (t, x)) : 'a =
    let rec loop
        : type a.
          a Caqti_type.t
          -> a
          -> Model.any_field list
          -> (string * Yojson.Safe.t) list
          -> (string * Yojson.Safe.t) list
      =
     fun t x fields result ->
      (* print_endline *)
      (* @@ (CCList.head_opt fields *)
      (*    |> Option.map Model.field_name *)
      (*    |> Option.value ~default:""); *)
      (* print_endline @@ Yojson.Safe.to_string (`Assoc result); *)
      (* print_endline @@ Caqti_type.show t; *)
      (* print_endline "\n\n\n"; *)
      match t, x, fields with
      | Caqti_type.Unit, (), [] -> result
      | Caqti_type.(Field String), v, AnyField (name, (_, Email _)) :: _ ->
        List.cons (name, `String v) result
      | Caqti_type.(Field String), v, AnyField (name, (_, String _)) :: _ ->
        List.cons (name, `String v) result
      | Caqti_type.(Field String), v, AnyField (name, (_, Enum _)) :: _ ->
        List.cons (name, `List [ `String v ]) result
      | Caqti_type.(Field Int), v, AnyField (name, _) :: _ ->
        List.cons (name, `Int v) result
      | Caqti_type.(Field Bool), v, AnyField (name, (_, Boolean _)) :: _ ->
        List.cons (name, `Bool v) result
      | Caqti_type.(Field Ptime), v, AnyField (name, (_, Timestamp _)) :: _ ->
        List.cons (name, Model.Ptime.to_yojson v) result
      | Caqti_type.(Tup2 (t2, t)), (vs, v), field :: fields ->
        let result = loop t v [ field ] result in
        loop t2 vs fields result
      | type_, _, AnyField (name, _) :: _ ->
        failwith
        @@ Format.sprintf
             "failed to parse field %s of type %s, fields left: %d"
             name
             (Caqti_type.show type_)
             (List.length fields)
      | _, _, [] -> result
    in
    let json = `Assoc (loop t x (List.rev model.fields) []) in
    (* print_endline (Yojson.Safe.show json); *)
    (* print_endline (json |> Yojson.Safe.to_string); *)
    json
    |> model.of_yojson
    |> Result.map_error @@ Format.sprintf "failed to decode dynparam %s"
    |> CCResult.get_or_failwith
  ;;
end

let select_stmt (model : 'a Model.t) (select : P.select) =
  let rec where (filter : P.filter) =
    match filter with
    (* TODO implement join *)
    | P.Filter { op; field_name; _ } ->
      let op =
        match op with
        | Eq -> "="
        | Gt -> ">"
        | Lt -> "<"
        | Like -> "LIKE"
      in
      Format.sprintf "%s %s %s" field_name op "?"
    | P.And [] | P.Or [] -> ""
    | P.And fs ->
      fs |> List.map where |> String.concat " AND " |> Format.sprintf "(%s)"
    | P.Or fs ->
      fs |> List.map where |> String.concat " OR " |> Format.sprintf "(%s)"
  in
  let where =
    select.filter
    |> Option.map where
    |> Option.map (Format.sprintf " WHERE %s")
    |> Option.value ~default:""
  in
  let order_by =
    select.order_by
    |> List.map (function
           | P.Desc c -> Format.sprintf "DESC %s" c
           | P.Asc c -> Format.sprintf "ASC %s" c)
    |> String.concat ", "
  in
  let limit =
    Option.map (Format.sprintf " LIMIT %d") select.limit
    |> Option.value ~default:""
  in
  let offset =
    Option.map (Format.sprintf " LIMIT %d") select.limit
    |> Option.value ~default:""
  in
  Format.sprintf
    "SELECT * FROM %s%s%s%s%s"
    model.name
    where
    order_by
    limit
    offset
;;

let insert_stmt (model : 'a Model.t) : string =
  let cols_stmt, vals_stmt =
    model.fields
    |> List.map (fun (AnyField (name, _) : Model.any_field) -> name, "?")
    |> List.split
  in
  let cols_stmt = String.concat ", " cols_stmt in
  let vals_stmt = String.concat ", " vals_stmt in
  Format.sprintf
    "INSERT INTO %s (%s) VALUES (%s) RETURNING id"
    model.name
    cols_stmt
    vals_stmt
;;

let update_stmt _ = failwith "todo update_stmt"

let insert
    (type a)
    (module Db : Caqti_lwt.CONNECTION)
    (model : a Model.t)
    (v : a)
    : int Lwt.t
  =
  let stmt = insert_stmt model in
  let dyn =
    List.fold_left
      (fun a (b : Model.any_field * Yojson.Safe.t) ->
        Model.(
          Caqti_type.(
            match b with
            | AnyField (_, (_, Integer _)), `Int v
            | AnyField (_, (_, Foreign_key _)), `Int v -> Dynparam.add int v a
            | AnyField (_, (_, Boolean _)), `Bool v -> Dynparam.add bool v a
            | AnyField (_, (_, Email _)), `String v
            | AnyField (_, (_, String _)), `String v -> Dynparam.add string v a
            | AnyField (_, (_, Enum _)), `List [ `String v ] ->
              Dynparam.add string v a
            | AnyField (_, (_, Timestamp _)), `String v ->
              (match Ptime.of_rfc3339 v with
              | Ok (v, _, _) -> Dynparam.add ptime v a
              | Error _ ->
                failwith
                @@ Format.sprintf "invalid ptime in model %s: %s" model.name v)
            | AnyField (name, _), v ->
              failwith
              @@ Format.sprintf
                   "could not parse field %s with value %s of model %s while \
                    inserting"
                   name
                   (Yojson.Safe.to_string v)
                   model.name)))
      Dynparam.empty
      (List.rev (Model.fields model v))
  in
  let (Dynparam.Pack (pt, pv)) = dyn in
  let req = Caqti_request.Infix.(pt ->! Caqti_type.int) @@ stmt in
  Db.find req pv
  |> Lwt_result.map_err Caqti_error.show
  |> Lwt.map CCResult.get_or_failwith
;;

let update
    (type a)
    (module Db : Caqti_lwt.CONNECTION)
    (model : a Model.t)
    (v : a)
    : int Lwt.t
  =
  model |> ignore;
  v |> ignore;
  failwith "todo update()"
;;

let find_opt
    (type a)
    (module Db : Caqti_lwt.CONNECTION)
    (model : a Model.t)
    (select : P.select)
    : (int * a) option Lwt.t
  =
  let stmt = select_stmt model select in
  let rec where filter dyn =
    match filter with
    | Some (P.And []) | Some (P.Or []) | None -> dyn
    | Some (P.Filter { value; _ }) ->
      (match value with
      | `String v -> Dynparam.add Caqti_type.string v dyn
      | `Bool v -> Dynparam.add Caqti_type.bool v dyn
      | `Int v -> Dynparam.add Caqti_type.int v dyn
      | _ -> failwith "can't map this Yojson value to caqti")
    | Some (P.And filters) ->
      List.fold_left (fun a b -> where (Some b) a) dyn filters
    | Some (P.Or filters) ->
      List.fold_left (fun a b -> where (Some b) a) dyn filters
  in
  let dyn_params = where select.filter Dynparam.empty in
  let (Dynparam.Pack (pt, pv)) = dyn_params in
  let dyn_model : Dynparam.t =
    List.fold_left
      (fun a b ->
        match b with
        (* TODO use Dyntype to get rid of default value *)
        | Model.AnyField (_, (_, Model.Integer _))
        | Model.AnyField (_, (_, Model.Foreign_key _)) ->
          Dynparam.add Caqti_type.int 0 a
        | Model.AnyField (_, (_, Model.String _))
        | Model.AnyField (_, (_, Model.Enum _))
        | Model.AnyField (_, (_, Model.Email _)) ->
          Dynparam.add Caqti_type.string "" a
        | Model.AnyField (_, (_, Model.Timestamp _)) ->
          Dynparam.add Caqti_type.ptime (Ptime_clock.now ()) a
        | Model.AnyField (_, (_, Model.Boolean _)) ->
          Dynparam.add Caqti_type.bool false a)
      (Dynparam.Pack (Caqti_type.int, 0))
      model.fields
  in
  let (Dynparam.Pack (pm, _)) = dyn_model in
  (* print_endline @@ Caqti_type.show pm; *)
  let req = Caqti_request.Infix.(pt ->? pm) @@ stmt in
  let%lwt res =
    Db.collect_list req pv
    |> Lwt_result.map_err Caqti_error.show
    |> Lwt.map CCResult.get_or_failwith
  in
  Lwt.return
  @@
  match res with
  | [ res ] ->
    let v = Dynparam.instance model (Dynparam.Pack (pm, res)) in
    Some (1, v)
  | _ -> None
;;
