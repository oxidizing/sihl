type cleaner = Core_db.connection -> unit Core_db.db_result

module Registry = struct
  let registry : cleaner list ref = ref []

  let get_all () = !registry

  let register cleaner = registry := List.cons cleaner !registry

  let register_cleaners cleaners =
    registry := List.concat [ !registry; cleaners ]
end

module Meta = struct
  type t = { total : int } [@@deriving show, eq, fields, make]
end

let set_fk_check connection status =
  let module Connection = (val connection : Caqti_lwt.CONNECTION) in
  let request =
    Caqti_request.exec Caqti_type.bool
      {sql|
        SET FOREIGN_KEY_CHECKS = ?;
           |sql}
  in
  Connection.exec request status

let register_cleaner _ cleaner =
  Registry.register cleaner;
  Lwt.return @@ Ok ()

let register_cleaners _ cleaners =
  Registry.register_cleaners cleaners;
  Lwt.return @@ Ok ()

let clean_all req =
  let ( let* ) = Lwt_result.bind in
  let cleaners = Registry.get_all () in
  let rec clean_repos cleaners =
    match cleaners with
    | [] -> Lwt.return @@ Ok ()
    | cleaner :: cleaners ->
        let* () = cleaner |> Core.Db.query_db req in
        clean_repos cleaners
  in
  clean_repos cleaners
