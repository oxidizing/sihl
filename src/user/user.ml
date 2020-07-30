open Base
include User_core.User
module Sig = User_sig
module Authz = User_authz
module Service = User_service
module Seed = User_seed
module PasswordReset = User_password_reset

let ctx_add_user user ctx = Core.Ctx.add ctx_key user ctx

let require_user ctx =
  Core.Ctx.find ctx_key ctx |> Result.of_option ~error:"User not authenticated"

let find_user ctx = Core.Ctx.find ctx_key ctx
