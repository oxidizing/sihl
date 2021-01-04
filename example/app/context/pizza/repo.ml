open Lwt.Syntax

let get_pizza_request =
  Caqti_request.find
    Caqti_type.string
    Caqti_type.(tup4 string string ptime ptime)
    {sql|
        SELECT
          uuid as id,
          name,
          created_at,
          updated_at
        FROM pizzas
        WHERE uuid = ?::uuid
        |sql}
;;

let get_pizza connection ~id =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  let* pizza = Connection.find get_pizza_request id in
  match pizza with
  | Ok pizza -> Lwt.return pizza
  | Error err -> failwith @@ Caqti_error.show err
;;

let get_ingredients_for_pizza_request =
  Caqti_request.collect
    Caqti_type.string
    Caqti_type.(tup4 string string ptime ptime)
    {sql|
        SELECT
          pizza_id,
          ingredient,
          created_at,
          updated_at
        FROM pizzas_ingredients
       WHERE pizza_id = ?::uuid
        |sql}
;;

let get_ingredients_for_pizza ~id =
  Sihl.Database.query (fun connection ->
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let* ingredients = Connection.collect_list get_ingredients_for_pizza_request id in
      match ingredients with
      | Ok pizza -> Lwt.return pizza
      | Error err -> failwith @@ Caqti_error.show err)
;;

let insert_request_pizzas =
  Caqti_request.exec
    Caqti_type.(tup4 string string ptime ptime)
    {sql|
        INSERT INTO pizzas (
          uuid,
          name,
          created_at,
          updated_at
        ) VALUES (
          $1,
          $2,
          $3,
          $4
        )
        |sql}
;;

let insert_request_pizzas_ingredients =
  Caqti_request.exec
    Caqti_type.(tup4 string string ptime ptime)
    {sql|
        INSERT INTO pizzas_ingredients (
          pizza_id,
          ingredient,
          created_at,
          updated_at
        ) VALUES (
          $1,
          $2,
          $3,
          $4
        )
        |sql}
;;

let insert_pizza pizza =
  let pizza_ingredients =
    List.map (fun ingr -> pizza.Model.id, ingr) pizza.Model.ingredients
  in
  let pizza_tup =
    pizza.Model.id, pizza.Model.name, pizza.Model.created_at, pizza.Model.updated_at
  in
  Sihl.Database.transaction (fun connection ->
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let* res = Connection.exec insert_request_pizzas pizza_tup in
      let () =
        match res with
        | Ok hm -> hm
        | Error err -> failwith @@ Caqti_error.show err
      in
      let* res =
        Connection.populate
          ~table:"pizzas_ingredients"
          ~columns:[ "pizza_id"; "ingredient" ]
          Caqti_type.(tup2 string string)
          (Caqti_lwt.Stream.of_list pizza_ingredients)
      in
      let () =
        match res with
        | Ok _ -> ()
        | Error (`Congested _) -> Logs.err (fun m -> m "Congested")
        | res ->
          (match Caqti_error.uncongested res with
          | Ok _ -> ()
          | Error err -> failwith @@ Caqti_error.show err)
      in
      let* id, name, created_at, updated_at = get_pizza connection ~id:pizza.Model.id in
      let* ingredients =
        get_ingredients_for_pizza ~id:pizza.Model.id
        |> Lwt.map (List.map (fun (_, ingr, _, _) -> ingr))
      in
      Lwt.return @@ Model.make ~id ~name ~ingredients ~created_at ~updated_at ())
;;

let clean_request = Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE pizzas CASCADE;"

let clean () =
  Sihl.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
      let* cleaned = Connection.exec clean_request () in
      match cleaned with
      | Ok cleaned -> Lwt.return cleaned
      | Error err -> failwith @@ Caqti_error.show err)
;;
