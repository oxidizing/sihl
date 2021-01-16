let registered_cleaners : (unit -> unit Lwt.t) list ref = ref []

let register_cleaner cleaner =
  registered_cleaners := List.cons cleaner !registered_cleaners
;;

let register_cleaners cleaners =
  registered_cleaners := List.concat [ !registered_cleaners; cleaners ]
;;

let clean_all () =
  let open Lwt.Syntax in
  let cleaners = !registered_cleaners in
  let rec clean_repos cleaners =
    match cleaners with
    | [] -> Lwt.return ()
    | cleaner :: cleaners ->
      let* () = cleaner () in
      clean_repos cleaners
  in
  clean_repos cleaners
;;
