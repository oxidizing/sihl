let postgresql_migrations_up =
  [ {sql|CREATE TABLE IF NOT EXISTS user_users (
  id          SERIAL UNIQUE,
  email       VARCHAR(255) NOT NULL,
  short_name  VARCHAR(255) NOT NULL,
  long_name   VARCHAR(255) NOT NULL,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)|sql}
  ; {sql|CREATE TRIGGER OR REPLACE update_users_updated_at
BEFORE UPDATE ON customer
FOR EACH ROW EXECUTE PROCEDURE
update_updated_at_column()|sql}
  ]
;;

let postgresql_migrations_down =
  [ "DROP TABLE IF EXISTS user_users"
  ; "DROP TRIGGER IF EXISTS update_users_updated_at"
  ]
;;

let mariadb_migrations_up =
  [ {sql|CREATE TABLE IF NOT EXISTS user_users (
  id          BIGINT UNSIGNED NOT NULL AUTOINCREMENT,
  email       VARCHAR(255) NOT NULL,
  short_name  VARCHAR(255) NOT NULL,
  long_name   VARCHAR(255) NOT NULL,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
)|sql}
  ]
;;

let mariadb_migrations_down = [ "DROP TABLE IF EXISTS user_users;" ]

let migrations = function
  | Config.Postgresql -> postgresql_migrations_up, postgresql_migrations_down
  | Config.Mariadb -> mariadb_migrations_up, mariadb_migrations_down
  | Config.Sqlite -> failwith "sqlite is not supported yet"
;;

let authentication_required = Obj.magic
let configure _ = ()

type role =
  | User
  | Staff
  | Superuser
[@@deriving yojson]

type t =
  { id : int
  ; role : role
  ; email : string
  ; short_name : string
  ; full_name : string
  ; created_at : Model.Ptime.t
  ; updated_at : Model.Ptime.t
  }
[@@deriving fields, yojson]

let schema =
  Model.
    [ int ~primary_key:true Fields.id
    ; enum role_of_yojson role_to_yojson Fields.role
    ; email Fields.email
    ; string Fields.full_name
    ; string ~max_length:80 Fields.short_name
    ; timestamp ~default:Now Fields.created_at
    ; timestamp ~default:Now ~update:true Fields.updated_at
    ]
;;

let t = Model.create to_yojson of_yojson "user" Fields.names schema

type request_user =
  | AnonymousUser
  | AuthenticatedUser of t
