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
  module Http = Web_http
  module Request = Opium.Request
  module Response = Opium.Response
  module Body = Opium.Body
  module Router = Opium.Router
  module Route = Opium.Route

  module Bearer_token = struct
    let find = Web_bearer_token.find
    let find_opt = Web_bearer_token.find_opt
    let set = Web_bearer_token.set
  end

  module Csrf = struct
    exception Csrf_token_not_found = Web_csrf.Csrf_token_not_found

    let find = Web_csrf.find
  end

  module Flash = struct
    exception Flash_not_found = Web_flash.Flash_not_found

    let find_alert = Web_flash.find_alert
    let set_alert = Web_flash.set_alert
    let find_notice = Web_flash.find_notice
    let set_notice = Web_flash.set_notice
    let find_custom = Web_flash.find_custom
    let set_custom = Web_flash.set_custom
  end

  module Form = struct
    type body = Web_form.body

    let pp = Web_form.pp

    exception Parsed_body_not_found = Web_form.Parsed_body_not_found

    let find_all = Web_form.find_all
    let find = Web_form.find
    let consume = Web_form.consume
  end

  module Htmx = struct
    exception Exception = Web_htmx.Exception

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
    let add_htmx_resp_header = Web_htmx.add_htmx_resp_header
  end

  module Id = struct
    exception Id_not_found = Web_id.Id_not_found

    let find = Web_id.find
    let find_opt = Web_id.find_opt
    let set = Web_id.set
  end

  module Json = struct
    exception Json_body_not_found = Web_json.Json_body_not_found

    let find = Web_json.find
    let find_opt = Web_json.find_opt
    let set = Web_json.set
  end

  module Session = struct
    exception Session_not_found = Web_session.Session_not_found

    let find = Web_session.find
    let set = Web_session.set
  end

  module User = struct
    let find = Web_user.find
    let find_opt = Web_user.find_opt
  end

  module Middleware = struct
    (* TODO [jerben] Move this to sihl-authorization or sihl-user *)
    let authorization_user = Web_authorization.user

    (* TODO [jerben] Move this to sihl-authorization or sihl-user *)
    let authorization_admin = Web_authorization.admin
    let bearer_token = Web_bearer_token.middleware
    let csrf = Web_csrf.middleware
    let error = Web_error.middleware
    let flash = Web_flash.middleware
    let form = Web_form.middleware
    let htmx = Web_htmx.middleware
    let id = Web_id.middleware
    let json = Web_json.middleware
    let session = Web_session.middleware
    let static_file = Web_static.middleware
    let user = Web_user.middleware
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
