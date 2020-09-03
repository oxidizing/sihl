open Data_repo_core
open Lwt.Syntax

module Registry = struct
  let registry : cleaner list ref = ref []

  let get_all () = !registry

  let register cleaner = registry := List.cons cleaner !registry

  let register_cleaners cleaners =
    registry := List.concat [ !registry; cleaners ]
end

let register_cleaner cleaner = Registry.register cleaner |> ignore

let register_cleaners cleaners = Registry.register_cleaners cleaners |> ignore

let lifecycle =
  Core.Container.Lifecycle.make "repo"
    (fun ctx -> Lwt.return ctx)
    (fun _ -> Lwt.return ())

let clean_all ctx =
  let cleaners = Registry.get_all () in
  let rec clean_repos cleaners =
    match cleaners with
    | [] -> Lwt.return ()
    | cleaner :: cleaners ->
        let* () = cleaner ctx in
        clean_repos cleaners
  in
  clean_repos cleaners
