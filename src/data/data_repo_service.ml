open Data_repo_core

let ( let* ) = Lwt_result.bind

module Registry = struct
  let registry : cleaner list ref = ref []

  let get_all () = !registry

  let register cleaner = registry := List.cons cleaner !registry

  let register_cleaners cleaners =
    registry := List.concat [ !registry; cleaners ]
end

module Service : Data_repo_sig.SERVICE = struct
  let on_init _ = Lwt_result.return ()

  let on_start _ = Lwt_result.return ()

  let on_stop _ = Lwt_result.return ()

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
          let* () = cleaner ctx in
          clean_repos cleaners
    in
    clean_repos cleaners
end
