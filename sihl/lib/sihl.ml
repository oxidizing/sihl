module Command = Command
module Config = Config
module Model = Model
module Test = Test
module User = User
module Web = Web

let run (module Config : Config.CONFIG) = Obj.magic
