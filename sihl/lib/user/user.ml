let authentication_required = Obj.magic
let configure _ = ()

type role =
  | User
  | Staff
  | Superuser
[@@deriving yojson]

type t =
  { role : role
  ; email : string
  ; short_name : string
  ; full_name : string
  ; password : string
  ; created_at : Model.Ptime.t
  ; updated_at : Model.Ptime.t
  }
[@@deriving fields, yojson, make]

let schema =
  Model.
    [ enum role_of_yojson role_to_yojson Fields.role
    ; email Fields.email
    ; string Fields.full_name
    ; string ~max_length:80 Fields.short_name
    ; string ~max_length:80 Fields.password
    ; timestamp ~default:Now Fields.created_at
    ; timestamp ~default:Now ~update:true Fields.updated_at
    ]
;;

let t = Model.create to_yojson of_yojson "users" Fields.names schema

type request =
  | AnonymousUser
  | AuthenticatedUser of t

let show = Model.show t
let user_field = Dream.new_field ~name:"user" ~show_value:show ()

module View = struct
  let login_required
      ?(login_url : string = Config.login_url ())
      (views : (Dream.method_ * Dream.handler) list)
      : (Dream.method_ * Dream.handler) list
    =
    List.map
      (fun (meth_, handler) ->
        ( meth_
        , fun req ->
            match Dream.session_field req "user" with
            | None -> Dream.redirect req login_url
            | Some user_id ->
              let%lwt _, user =
                Dream.sql req (fun conn ->
                    Query.find_by_id conn t (int_of_string user_id))
              in
              Dream.set_field req user_field user;
              handler req ))
      views
  ;;
end
