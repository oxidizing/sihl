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
    let find = Web_csrf.find
  end

  module Flash = struct
    let find_alert = Web_flash.find_alert
    let set_alert = Web_flash.set_alert
    let find_notice = Web_flash.find_notice
    let set_notice = Web_flash.set_notice
    let find = Web_flash.find
    let set = Web_flash.set
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

    type form = (string * string option * string option) list

    let resource_of_service = Web_rest.resource_of_service
    let resource_of_controller = Web_rest.resource_of_controller
    let find_form = Web_rest.Form.find

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
  end

  module Id = struct
    let find = Web_id.find
  end

  module Session = struct
    let find = Web_session.find
    let set = Web_session.set
  end

  module Middleware = struct
    let csrf = Web_csrf.middleware
    let error = Web_error.middleware
    let flash = Web_flash.middleware
    let id = Web_id.middleware
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
