module Lifecycle = struct
  type t = {
    module_name : string;
    dependencies : t list;
    start : Core_ctx.t -> Core_ctx.t Lwt.t;
    stop : Core_ctx.t -> unit Lwt.t;
  }
  [@@deriving fields]

  let make module_name ?(dependencies = []) start stop =
    { module_name; dependencies; start; stop }
end

module type SERVICE = sig
  val lifecycle : Lifecycle.t
end

let collect_all_lifecycles services =
  let rec collect_lifecycles lifecycle =
    match lifecycle |> Lifecycle.dependencies with
    | [] -> [ lifecycle ]
    | lifecycles ->
        List.cons lifecycle
          ( lifecycles
          |> List.map (fun lifecycle -> collect_lifecycles lifecycle)
          |> List.concat )
  in
  services
  |> List.map (fun (module Service : SERVICE) ->
         Service.lifecycle |> collect_lifecycles)
  |> List.concat
  |> List.map (fun lifecycle -> (Lifecycle.module_name lifecycle, lifecycle))
  |> Base.Map.of_alist_reduce (module Base.String) ~f:(fun _ b -> b)

let top_sort_lifecycles services =
  let lifecycles = collect_all_lifecycles services in
  let lifecycle_graph =
    lifecycles |> Base.Map.to_alist
    |> List.map (fun (name, lifecycle) ->
           let dependencies =
             lifecycle |> Lifecycle.dependencies
             |> List.map Lifecycle.module_name
           in
           (name, dependencies))
  in
  match Tsort.sort lifecycle_graph with
  | Tsort.Sorted sorted ->
      sorted
      |> List.map (fun name -> Base.Map.find lifecycles name |> Option.get)
      |> List.rev
  | Tsort.ErrorCycle remaining_names ->
      let msg = String.concat ", " remaining_names in
      failwith
      @@ "CONTAINER: Cycle detected while starting services. These are the \
          services after the cycle: " ^ msg

let start_services services =
  Logs.info (fun m -> m "CONTAINER: Start services");
  let lifecycles = services |> top_sort_lifecycles in
  let ctx = Core_ctx.empty in
  let rec loop ctx lifecycles =
    match lifecycles with
    | lifecycle :: lifecycles ->
        let f = Lifecycle.start lifecycle in
        Lwt.bind (f ctx) (fun ctx -> loop ctx lifecycles)
    | [] -> Lwt.return ctx
  in
  loop ctx lifecycles |> Lwt.map (fun ctx -> (services, ctx))

let stop_services ctx services =
  Logs.info (fun m -> m "CONTAINER: Stop services");
  let lifecycles = services |> top_sort_lifecycles in
  let rec loop lifecycles =
    match lifecycles with
    | lifecycle :: lifecycles ->
        let f = Lifecycle.stop lifecycle in
        Lwt.bind (f ctx) (fun () -> loop lifecycles)
    | [] -> Lwt.return ()
  in
  loop lifecycles
