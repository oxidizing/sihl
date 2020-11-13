open Model
open Lwt.Syntax
module Sig = Sig

module Registry = struct
  let registry : cleaner list ref = ref []
  let get_all () = !registry
  let register cleaner = registry := List.cons cleaner !registry
  let register_cleaners cleaners = registry := List.concat [ !registry; cleaners ]
end

let register_cleaner cleaner = Registry.register cleaner |> ignore
let register_cleaners cleaners = Registry.register_cleaners cleaners |> ignore

let clean_all () =
  let cleaners = Registry.get_all () in
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
