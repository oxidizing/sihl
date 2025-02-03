let singularize str =
  Option.value ~default:str (CCString.chop_suffix ~suf:"s" str)
;;

let capitalize = CCString.capitalize_ascii

module Form = struct
  type t = (string * string option * string option) list
  [@@deriving yojson, show, eq]

  let set
        ?(key = "_form")
        (errors : Conformist.error list)
        (urlencoded : (string * string list) list)
        resp
    =
    let t =
      List.map
        (fun (k, v) ->
           errors
           |> List.find_opt (fun (field, _, _) -> String.equal field k)
           |> Option.map (fun (field, input, value) ->
             field, CCList.head_opt input, Some value)
           |> Option.value ~default:(k, CCList.head_opt v, None))
        urlencoded
    in
    let json = t |> to_yojson |> Yojson.Safe.to_string in
    Web_flash.set [ key, json ] resp
  ;;

  let find_form ?(key = "_form") req =
    match Web_flash.find key req with
    | None -> []
    | Some json ->
      let yojson =
        try Some (Yojson.Safe.from_string json) with
        | _ -> None
      in
      (match yojson with
       | Some yojson ->
         (match of_yojson yojson with
          | Error _ -> []
          | Ok form -> form)
       | None -> [])
  ;;

  let find (k : string) (form : t) : string option * string option =
    form
    |> List.find_opt (fun (k', _, _) -> String.equal k k')
    |> Option.map (fun (_, value, error) -> value, error)
    |> Option.value ~default:(None, None)
  ;;
end

module type SERVICE = sig
  type t

  val find : string -> t option Lwt.t

  val search
    :  ?filter:string
    -> ?sort:[ `Desc | `Asc ]
    -> ?limit:int
    -> ?offset:int
    -> unit
    -> (t list * int) Lwt.t

  val insert : t -> (t, string) Result.t Lwt.t
  val update : string -> t -> (t, string) result Lwt.t
  val delete : t -> (unit, string) result Lwt.t
end

module Query = struct
  type sort =
    [ `Desc
    | `Asc
    ]
  [@@deriving show, eq]

  type t =
    { filter : string option
    ; limit : int option
    ; offset : int option
    ; sort : sort option
    }
  [@@deriving show, eq]

  let default_limit = 50

  let sort_of_string (str : string) : sort option =
    match str with
    | "asc" -> Some `Asc
    | "desc" -> Some `Desc
    | _ -> None
  ;;

  let string_of_sort = function
    | `Desc -> "desc"
    | `Asc -> "asc"
  ;;

  let of_request req =
    let ( let* ) = Option.bind in
    let filter =
      let* filter = Opium.Request.query "filter" req in
      if String.equal "" filter then None else Some filter
    in
    let limit =
      let* limit = Opium.Request.query "limit" req in
      let* limit = if String.equal "" limit then None else Some limit in
      int_of_string_opt limit
    in
    let offset =
      let* offset = Opium.Request.query "offset" req in
      let* offset = if String.equal "" offset then None else Some offset in
      int_of_string_opt offset
    in
    let sort =
      let* sort = Opium.Request.query "sort" req in
      let* sort = if String.equal "" sort then None else Some sort in
      sort_of_string sort
    in
    { filter; limit; offset; sort }
  ;;

  let to_query_string (query : t) : string =
    Uri.empty
    |> (fun uri ->
    match query.filter with
    | Some filter -> Uri.add_query_param uri ("filter", [ filter ])
    | None -> uri)
    |> (fun uri ->
    match query.limit with
    | Some limit -> Uri.add_query_param uri ("limit", [ string_of_int limit ])
    | None -> uri)
    |> (fun uri ->
    match query.offset with
    | Some offset -> Uri.add_query_param uri ("offset", [ string_of_int offset ])
    | None -> uri)
    |> (fun uri ->
    match query.sort with
    | Some sort -> Uri.add_query_param uri ("sort", [ string_of_sort sort ])
    | None -> uri)
    |> Uri.to_string
  ;;

  let next_page (query : t) (total : int) : t option =
    let limit = Option.value ~default:default_limit query.limit in
    let offset = Option.value ~default:0 query.offset in
    if limit + offset <= total
    then Some { query with offset = Some (limit + offset) }
    else None
  ;;

  let previous_page (query : t) : t option =
    let limit = Option.value ~default:default_limit query.limit in
    let offset = Option.value ~default:0 query.offset in
    if offset - limit >= 0
    then Some { query with offset = Some (offset - limit) }
    else None
  ;;

  let last_page (query : t) (total : int) : t option =
    let limit = Option.value ~default:default_limit query.limit in
    let offset = Option.value ~default:0 query.offset in
    if offset < total - limit
    then Some { query with offset = Some (total - 1) }
    else None
  ;;

  let first_page (query : t) : t option =
    let offset = Option.value ~default:0 query.offset in
    if offset > 0 then Some { query with offset = Some 0 } else None
  ;;
end

module type VIEW = sig
  type t

  val skip_index_fetch : bool

  val index
    :  Rock.Request.t
    -> string
    -> t list * int
    -> Query.t
    -> [> Html_types.html ] Tyxml.Html.elt Lwt.t

  val new'
    :  Rock.Request.t
    -> string
    -> Form.t
    -> [> Html_types.html ] Tyxml.Html.elt Lwt.t

  val show : Rock.Request.t -> t -> [> Html_types.html ] Tyxml.Html.elt Lwt.t

  val edit
    :  Rock.Request.t
    -> string
    -> Form.t
    -> t
    -> [> Html_types.html ] Tyxml.Html.elt Lwt.t
end

module type CONTROLLER = sig
  type t

  val index : string -> Rock.Request.t -> Rock.Response.t Lwt.t
  val new' : ?key:string -> string -> Rock.Request.t -> Rock.Response.t Lwt.t

  val create
    :  string
    -> ('a, 'b, t) Conformist.t
    -> Rock.Request.t
    -> Rock.Response.t Lwt.t

  val show : string -> Rock.Request.t -> Rock.Response.t Lwt.t
  val edit : ?key:string -> string -> Rock.Request.t -> Rock.Response.t Lwt.t

  val update
    :  string
    -> ('a, 'b, t) Conformist.t
    -> Rock.Request.t
    -> Rock.Response.t Lwt.t

  val delete' : string -> Rock.Request.t -> Rock.Response.t Lwt.t
end

module MakeController (Service : SERVICE) (View : VIEW with type t = Service.t) =
struct
  exception Exception of string

  type t = Service.t

  let fetch_csrf name req =
    match Web_csrf.find req with
    | None ->
      Logs.err (fun m ->
        m "CSRF middleware not installed for resource '%s'" name);
      failwith "CSRF middleware not installed"
    | Some token -> token
  ;;

  let index name req =
    let open Query in
    let csrf = fetch_csrf name req in
    let ({ filter; limit; offset; sort } as query) = of_request req in
    let%lwt result =
      if View.skip_index_fetch
      then Lwt.return ([], 0)
      else Service.search ?filter ?limit ?offset ?sort ()
    in
    let%lwt html = View.index req csrf result query in
    Lwt.return @@ Opium.Response.of_html html
  ;;

  let new' ?key name req =
    let csrf = fetch_csrf name req in
    let form = Form.find_form ?key req in
    let%lwt html = View.new' req csrf form in
    Lwt.return @@ Opium.Response.of_html html
  ;;

  let create name schema req =
    let%lwt urlencoded = Opium.Request.to_urlencoded req in
    let thing = Conformist.decode_and_validate schema urlencoded in
    match thing with
    | Ok thing ->
      let%lwt thing = Service.insert thing in
      (match thing with
       | Ok _ ->
         Opium.Response.redirect_to (Format.sprintf "/%s" name)
         |> Web_flash.set_notice
              (Format.sprintf "Successfully added %s" (singularize name))
         |> Lwt.return
       | Error msg ->
         Opium.Response.redirect_to (Format.sprintf "/%s/new" name)
         |> Form.set [] urlencoded
         |> Web_flash.set_alert msg
         |> Lwt.return)
    | Error errors ->
      Opium.Response.redirect_to (Format.sprintf "/%s/new" name)
      |> Web_flash.set_alert "Some of the input is invalid"
      |> Form.set errors urlencoded
      |> Lwt.return
  ;;

  let show name req =
    let id = Opium.Router.param req "id" in
    let%lwt thing = Service.find id in
    match thing with
    | Some thing ->
      let%lwt html = View.show req thing in
      Lwt.return @@ Opium.Response.of_html html
    | None ->
      Opium.Response.redirect_to (Format.sprintf "/%s" name)
      |> Web_flash.set_alert
           (Format.sprintf
              "%s with id '%s' not found"
              (singularize (capitalize name))
              id)
      |> Lwt.return
  ;;

  let edit ?key name req =
    let id = Opium.Router.param req "id" in
    let%lwt thing = Service.find id in
    match thing with
    | Some thing ->
      let csrf = fetch_csrf name req in
      let form = Form.find_form ?key req in
      let%lwt html = View.edit req csrf form thing in
      Lwt.return @@ Opium.Response.of_html html
    | None ->
      Opium.Response.redirect_to (Format.sprintf "/%s" name)
      |> Web_flash.set_alert
           (Format.sprintf
              "%s with id '%s' not found"
              (singularize (capitalize name))
              id)
      |> Lwt.return
  ;;

  let update name schema req =
    let%lwt urlencoded = Opium.Request.to_urlencoded req in
    let thing = Conformist.decode_and_validate schema urlencoded in
    let id = Opium.Router.param req "id" in
    match thing with
    | Ok thing ->
      let%lwt updated = Service.update id thing in
      (match updated with
       | Ok _ ->
         Opium.Response.redirect_to (Format.sprintf "/%s/%s" name id)
         |> Web_flash.set_notice
              (Format.sprintf "Successfully updated %s" (singularize name))
         |> Lwt.return
       | Error msg ->
         Opium.Response.redirect_to (Format.sprintf "/%s/%s/edit" name id)
         |> Web_flash.set_alert msg
         |> Form.set [] urlencoded
         |> Lwt.return)
    | Error errors ->
      Opium.Response.redirect_to (Format.sprintf "/%s/%s/edit" name id)
      |> Web_flash.set_alert "Some of the input is invalid"
      |> Form.set errors urlencoded
      |> Lwt.return
  ;;

  let delete' name req =
    let id = Opium.Router.param req "id" in
    let query = Query.of_request req in
    let target_uri =
      Format.sprintf "/%s%s" name (Query.to_query_string query)
    in
    let%lwt thing = Service.find id in
    match thing with
    | None ->
      Opium.Response.redirect_to target_uri
      |> Web_flash.set_alert
           (Format.sprintf
              "%s with id '%s' not found"
              (singularize (capitalize name))
              id)
      |> Lwt.return
    | Some thing ->
      let%lwt result = Service.delete thing in
      (match result with
       | Ok () ->
         Opium.Response.redirect_to target_uri
         |> Web_flash.set_notice
              (Format.sprintf
                 "Successfully deleted %s '%s'"
                 (singularize name)
                 id)
         |> Lwt.return
       | Error msg ->
         Opium.Response.redirect_to target_uri
         |> Web_flash.set_notice
              (Format.sprintf
                 "Failed to delete %s: '%s'"
                 (singularize name)
                 msg)
         |> Lwt.return)
  ;;
end

type action =
  [ `Index
  | `Create
  | `New
  | `Edit
  | `Show
  | `Update
  | `Destroy
  ]

let router_of_action
      (type a)
      (module Controller : CONTROLLER with type t = a)
      name
      schema
      (action : action)
  =
  match action with
  | `Index -> Web.get (Format.sprintf "/%s" name) (Controller.index name)
  | `Create ->
    Web.post (Format.sprintf "/%s" name) (Controller.create name schema)
  | `New -> Web.get (Format.sprintf "/%s/new" name) (Controller.new' name)
  | `Edit -> Web.get (Format.sprintf "/%s/:id/edit" name) (Controller.edit name)
  | `Show -> Web.get (Format.sprintf "/%s/:id" name) (Controller.show name)
  | `Update ->
    Web.put (Format.sprintf "/%s/:id" name) (Controller.update name schema)
  | `Destroy ->
    Web.delete (Format.sprintf "/%s/:id" name) (Controller.delete' name)
;;

let routers_of_actions
      (type a)
      name
      schema
      (module Controller : CONTROLLER with type t = a)
      (actions : action list)
  =
  List.map (router_of_action (module Controller) name schema) actions
;;

let resource_of_controller
      (type a)
      ?only
      name
      schema
      (module Controller : CONTROLLER with type t = a)
  =
  match only with
  | None ->
    routers_of_actions
      name
      schema
      (module Controller)
      [ `Index; `Create; `New; `Edit; `Show; `Update; `Destroy ]
  | Some actions -> routers_of_actions name schema (module Controller) actions
;;

let resource_of_service
      (type a)
      ?only
      name
      schema
      ~view:(module View : VIEW with type t = a)
      (module Service : SERVICE with type t = a)
  =
  let module Controller = MakeController (Service) (View) in
  resource_of_controller ?only name schema (module Controller)
;;
