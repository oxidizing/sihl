module type ADMIN_SERVICE = sig
  val register_page : Admin_page.t -> unit

  val get_all_pages : unit -> Admin_page.t list
end

let registry_key = Core.Registry.Key.create "/admin/service"

module Service = struct
  let register_page page =
    match Core.Registry.fetch registry_key with
    | Some (module Service : ADMIN_SERVICE) -> Service.register_page page
    | None ->
        Logs.warn (fun m ->
            m
              "ADMIN: Could not register admin page, have you installed the \
               admin app?")

  let get_all_pages () =
    match Core.Registry.fetch registry_key with
    | Some (module Service : ADMIN_SERVICE) -> Service.get_all_pages ()
    | None ->
        Logs.warn (fun m ->
            m
              "ADMIN: Could not get admin pages, have you installed the admin \
               app?");
        []
end
