module Command = Command
module Config = Config
module Model = Model
module Test = Test
module User = User
module Form = Form
module View = View
module Query = Query
module Migration = Migration

let run (module Config : Config.CONFIG) = Obj.magic
