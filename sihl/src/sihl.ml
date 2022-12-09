module App = Core_app
module Cleaner = Core_cleaner
module Command = Core_command
module Configuration = Core_configuration
module Container = Core_container
module Log = Core_log
module Random = Core_random
module Schedule = Core_schedule
module Time = Core_time

module Web = struct
  include Web
  module Http = Web_http

  module Request = struct
    include Opium.Request

    let bearer_token req =
      match Opium.Request.header "authorization" req with
      | Some authorization ->
        (try Some (Scanf.sscanf authorization "Bearer %s" (fun b -> b)) with
         | _ -> None)
      | None -> None
    ;;
  end

  module Response = Opium.Response
  module Cookie = Opium.Cookie
  module Body = Opium.Body
  module Router = Opium.Router
  module Route = Opium.Route

  module Csrf = struct
    module Crypto = Web_csrf.Crypto

    let find = Web_csrf.find
    let find_exn = Web_csrf.find_exn
    let log_src = Web_csrf.log_src
  end

  module Flash = struct
    let find_alert = Web_flash.find_alert
    let set_alert = Web_flash.set_alert
    let find_notice = Web_flash.find_notice
    let set_notice = Web_flash.set_notice
    let find = Web_flash.find
    let set = Web_flash.set
    let log_src = Web_flash.log_src
  end

  module Rest = struct
    type action =
      [ `Index
      | `Create
      | `New
      | `Edit
      | `Show
      | `Update
      | `Destroy
      ]

    type query = Web_rest.Query.t =
      { filter : string option
      ; limit : int option
      ; offset : int option
      ; sort : [ `Desc | `Asc ] option
      }

    let of_request = Web_rest.Query.of_request
    let to_query_string = Web_rest.Query.to_query_string
    let next_page = Web_rest.Query.next_page
    let previous_page = Web_rest.Query.previous_page
    let last_page = Web_rest.Query.last_page
    let first_page = Web_rest.Query.first_page
    let query_filter q = q.filter
    let query_sort q = q.sort |> Option.map Web_rest.Query.string_of_sort
    let query_limit q = q.limit |> Option.map string_of_int
    let query_offset q = q.offset |> Option.map string_of_int

    type form = (string * string option * string option) list

    let find_form = Web_rest.Form.find
    let resource_of_service = Web_rest.resource_of_service
    let resource_of_controller = Web_rest.resource_of_controller

    module type SERVICE = sig
      include Web_rest.SERVICE
    end

    module type VIEW = sig
      include Web_rest.VIEW
    end

    module type CONTROLLER = sig
      include Web_rest.CONTROLLER
    end
  end

  module Htmx = struct
    let is_htmx = Web_htmx.is_htmx
    let current_url = Web_htmx.current_url
    let prompt = Web_htmx.prompt
    let target = Web_htmx.target
    let trigger_name = Web_htmx.trigger_name
    let trigger_req = Web_htmx.trigger_req
    let set_push = Web_htmx.set_push
    let set_redirect = Web_htmx.set_redirect
    let set_refresh = Web_htmx.set_refresh
    let set_trigger = Web_htmx.set_trigger
    let set_trigger_after_settle = Web_htmx.set_trigger_after_settle
    let set_trigger_after_swap = Web_htmx.set_trigger_after_swap
    let log_src = Web_csrf.log_src
  end

  module Id = struct
    let find = Web_id.find
  end

  module Session = struct
    let find = Web_session.find
    let set = Web_session.set
    let set_value = Web_session.set_value
    let update_or_set_value = Web_session.update_or_set_value
    let get_all = Web_session.get_all
    let log_src = Web_session.log_src
  end

  module Middleware = struct
    let csrf = Web_csrf.middleware

    type report = Web_error.report =
      { exn : string
      ; stack : string
      ; req_id : string
      ; req : string
      }

    let error = Web_error.middleware
    let error_log_src = Web_error.log_src
    let flash = Web_flash.middleware
    let id = Web_id.middleware
    let migration = Web_migration.middleware
    let migration_log_src = Web_migration.log_src
    let trailing_slash = Web_trailing_slash.middleware
    let static_file = Web_static.middleware
  end
end

module Database = struct
  include Database
  module Migration = Database_migration
end

module Contract = struct
  module Cache = Contract_cache
  module Database = Contract_database
  module Email = Contract_email
  module Email_template = Contract_email_template
  module Http = Contract_http
  module Migration = Contract_migration
  module Password_reset = Contract_password_reset
  module Queue = Contract_queue
  module Random = Contract_random
  module Schedule = Contract_schedule
  module Storage = Contract_storage
  module Token = Contract_token
  module User = Contract_user
end

module Test = struct
  module Session = Session
end
