open Base
module Sig = Sig

let registered_seeds = ref (Map.empty (module String))

exception Exception of string

module Make
    (Log : Log.Service.Sig.SERVICE)
    (CmdService : Cmd.Service.Sig.SERVICE) : Sig.SERVICE = struct
  let register_seed seed =
    registered_seeds :=
      Map.add_exn !registered_seeds ~key:(Seed_core.name seed) ~data:seed

  let register_seeds seeds =
    registered_seeds :=
      List.fold_left seeds ~init:!registered_seeds ~f:(fun m s ->
          Map.add_exn m ~key:(Seed_core.name s) ~data:s)

  let get_seeds () =
    !registered_seeds |> Map.to_alist |> List.map ~f:(fun (_, b) -> b)

  let run_seed ctx name =
    Log.debug (fun m -> m "SEED: Running seed %s" name);
    match Map.find !registered_seeds name with
    | Some seed ->
        let fn = Seed_core.fn seed in
        fn ctx
    | None ->
        Log.err (fun m -> m "SEED: Seed not found: %s" name);
        Log.info (fun m ->
            m
              "SEED: Have you registered the seed? Call \
               SeedService.register_seed or register the seed with the app \
               using App.with_seed.");
        raise @@ Exception "Seed not found"

  let seed_list =
    Cmd.make ~name:"seedlist" ~description:"List all registered seeds"
      ~fn:(fun _ ->
        let seeds = get_seeds () in
        seeds |> List.map ~f:Seed_core.show |> String.concat ~sep:"\n"
        |> Caml.print_endline;
        Lwt.return ())
      ()

  let seed_run =
    Cmd.make ~name:"seedrun" ~help:"<seed name>" ~description:"Run seed"
      ~fn:(fun args ->
        match args with
        | [ name ] ->
            let ctx = Core.Ctx.empty in
            run_seed ctx name
        | _ -> raise (Cmd.Invalid_usage "Usage: <seed name>"))
      ()

  let start ctx =
    CmdService.register_command seed_list;
    CmdService.register_command seed_run;
    Lwt.return ctx

  let stop _ = Lwt.return ()

  let lifecycle = Core.Container.Lifecycle.make "seed" ~start ~stop
end
