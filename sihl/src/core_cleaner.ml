let registered_cleaners
    : (?ctx:(string * string) list -> unit -> unit Lwt.t) list ref
  =
  ref []
;;

let register_cleaner cleaner =
  registered_cleaners := List.cons cleaner !registered_cleaners
;;

let register_cleaners cleaners =
  registered_cleaners := List.concat [ !registered_cleaners; cleaners ]
;;

let clean_all ?ctx () =
  let cleaners = !registered_cleaners in
  let rec clean_repos ?ctx cleaners =
    match cleaners with
    | [] -> Lwt.return ()
    | cleaner :: cleaners ->
      let%lwt () = cleaner ?ctx () in
      clean_repos cleaners
  in
  clean_repos ?ctx cleaners
;;
