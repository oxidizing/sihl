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

type request_user =
  | AnonymousUser
  | AuthenticatedUser of t
