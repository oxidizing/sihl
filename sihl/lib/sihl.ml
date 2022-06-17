module Command = Sihl__command.Command
module Config = Sihl__config.Config
module Model = Sihl__model.Model
module User = Sihl__user.User
module Form = Sihl__form.Form
module View = Sihl__view.View
module Query = Sihl__query.Query
module Migration = Sihl__migration.Migration
module Test = Sihl__test.Test

let run (module Config : Config.CONFIG) = Obj.magic

let middlewares middlewares req =
  List.fold_left (fun a b -> b a) req middlewares
;;
