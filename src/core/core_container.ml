open Base

module type SERVICE = sig
  val on_init : Core_ctx.t -> (unit, string) Lwt_result.t

  val on_start : Core_ctx.t -> (unit, string) Lwt_result.t

  val on_stop : Core_ctx.t -> (unit, string) Lwt_result.t
end

module Registry = struct
  let state = ref []

  let add service = state := List.concat [ !state; [ service ] ]

  let get_all () = !state
end

let register_services ctx services =
  Logs.info (fun m -> m "CONTAINER: Register services");
  let () = services |> List.map ~f:Registry.add |> ignore in
  let rec register ctx services =
    match services with
    | (module Service : SERVICE) :: services ->
        Lwt_result.bind (Service.on_init ctx) (fun () -> register ctx services)
    | [] -> Lwt_result.return ()
  in
  register ctx services

let start_services ctx =
  Logs.info (fun m -> m "CONTAINER: Start services");
  let rec start ctx services =
    match services with
    | (module Service : SERVICE) :: services ->
        Lwt_result.bind (Service.on_start ctx) (fun () -> start ctx services)
    | [] -> Lwt_result.return ()
  in
  let services = Registry.get_all () in
  start ctx services

let stop_services ctx =
  Logs.info (fun m -> m "CONTAINER: Stop services");
  let rec stop ctx services =
    match services with
    | (module Service : SERVICE) :: services ->
        Lwt_result.bind (Service.on_stop ctx) (fun () -> stop ctx services)
    | [] -> Lwt_result.return ()
  in
  let services = Registry.get_all () in
  stop ctx services
