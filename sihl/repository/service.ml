open Model
open Lwt.Syntax
module Sig = Sig

let registered_cleaners : cleaner list ref = ref []

let register_cleaner cleaner =
  registered_cleaners := List.cons cleaner !registered_cleaners
;;

let register_cleaners cleaners =
  registered_cleaners := List.concat [ !registered_cleaners; cleaners ]
;;

let clean_all () =
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

let start () = Lwt.return ()
let stop _ = Lwt.return ()
let lifecycle = Sihl_core.Container.Lifecycle.create "repo" ~start ~stop

let register ?(cleaners = []) () =
  register_cleaners cleaners;
  Sihl_core.Container.Service.create lifecycle
;;
