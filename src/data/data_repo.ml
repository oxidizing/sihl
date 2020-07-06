let ( let* ) = Lwt_result.bind

type cleaner = Data_db_core.connection -> (unit, string) Result.t Lwt.t

module Sig = Data_repo_sig

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

let register_cleaner _ cleaner =
  Registry.register cleaner;
  Lwt.return @@ Ok ()

let register_cleaners _ cleaners =
  Registry.register_cleaners cleaners;
  Lwt.return @@ Ok ()

let clean_all ctx =
  let cleaners = Registry.get_all () in
  let rec clean_repos cleaners =
    match cleaners with
    | [] -> Lwt.return @@ Ok ()
    | cleaner :: cleaners ->
        let* () = cleaner |> Data_db.query ctx in
        clean_repos cleaners
  in
  clean_repos cleaners
