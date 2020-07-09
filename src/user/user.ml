open Base
include User_core.User
module Sig = User_sig
module Authz = User_authz
module Service = User_service
module Seed = User_seed
module Cmd = User_cmd
module Admin = User_admin

let ctx_add_user user ctx = Core.Ctx.add ctx_key user ctx

let get = User_service.get

let get_by_email = User_service.get_by_email

let get_all = User_service.get_all

let update_password = User_service.update_password

let set_password = User_service.set_password

let update_details = User_service.update_details

let create_user = User_service.create_user

let create_admin = User_service.create_admin

let register = User_service.register

let login = User_service.login

let create_session_for _ = failwith "TODO create_session_for"

let require_user ctx =
  Core.Ctx.find ctx_key ctx |> Result.of_option ~error:"User not authenticated"

let find_user ctx = Core.Ctx.find ctx_key ctx
