module Command = Command
module Config = Config
module Model = Model
module User = User
module Form = Form
module View = View
module Query = Query
module Migration = Migration
module Test = Sihl_test.Test

let run (module Config : Config.CONFIG) = Obj.magic

let middlewares middlewares req =
  List.fold_left (fun a b -> b a) req middlewares
;;
