open Lwt.Syntax

let unique_keys _ () =
  let key1 : string Sihl.Core.Ctx.key = Sihl.Core.Ctx.create_key () in
  let key2 : string Sihl.Core.Ctx.key = Sihl.Core.Ctx.create_key () in
  let ctx =
    Sihl.Core.Ctx.empty ()
    |> Sihl.Core.Ctx.add key1 "value1"
    |> Sihl.Core.Ctx.add key2 "value2"
  in
  Alcotest.(
    check (option string) "has value" (Sihl.Core.Ctx.find key1 ctx) (Some "value1"));
  Alcotest.(
    check (option string) "has value" (Sihl.Core.Ctx.find key2 ctx) (Some "value2"));
  Lwt.return ()
;;

let replace_value _ () =
  let key : string Sihl.Core.Ctx.key = Sihl.Core.Ctx.create_key () in
  let ctx =
    Sihl.Core.Ctx.empty ()
    |> Sihl.Core.Ctx.add key "value1"
    |> Sihl.Core.Ctx.add key "value2"
  in
  Alcotest.(
    check (option string) "has value" (Sihl.Core.Ctx.find key ctx) (Some "value2"));
  Lwt.return ()
;;

type transaction =
  { queries : string list
  ; finalized : bool
  }

let transactions = Hashtbl.create 10

(* Setup mock database *)

module Database : sig
  type pool
  type connection

  val fetch : unit -> pool Lwt.t
  val fetch_connection : unit -> connection Lwt.t
  val query_on_pool : pool -> string -> unit Lwt.t
  val query_on_connection : connection -> string -> unit Lwt.t
  val finalize_transaction : connection -> unit Lwt.t
end = struct
  type pool = unit
  type connection = int

  let fetch () = Lwt.return ()
  let fetch_connection () = Lwt.return 42
  let query_on_pool _ _ = Lwt.return ()

  let query_on_connection connection query =
    let () =
      match Hashtbl.find_opt transactions connection with
      | Some transaction ->
        Hashtbl.add
          transactions
          connection
          { transaction with queries = List.cons query transaction.queries }
      | None ->
        Hashtbl.add transactions connection { queries = [ query ]; finalized = false }
    in
    Lwt.return ()
  ;;

  let finalize_transaction connection =
    let transaction = Hashtbl.find transactions connection in
    Hashtbl.add transactions connection { transaction with finalized = true };
    Lwt.return ()
  ;;
end

let query ctx query_str =
  let* connection =
    Sihl.Core.Ctx.handle_atomic
      ctx
      Database.fetch_connection
      Database.finalize_transaction
  in
  match connection with
  | Some connection -> Database.query_on_connection connection query_str
  | None ->
    let* pool = Database.fetch () in
    Database.query_on_pool pool query_str
;;

let atomic _ () =
  let ctx = Sihl.Core.Ctx.empty () in
  let* () =
    Sihl.Core.Ctx.atomic ctx (fun ctx ->
        let* () = query ctx "find all users" in
        query ctx "find all orders")
  in
  let transaction = Hashtbl.find transactions 42 in
  Alcotest.(
    check
      (list string)
      "is empty"
      [ "find all orders"; "find all users" ]
      transaction.queries);
  Alcotest.(check bool "was not finalized" true transaction.finalized);
  Lwt.return ()
;;
