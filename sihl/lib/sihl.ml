module Command = Sihl__command.Command
module Config = Sihl__config.Config
module Form = Sihl__form.Form
module Migration = Sihl__migration.Migration
module Model = Sihl__model.Model
module Query = Sihl__query.Query
module Test = Sihl__test.Test
module User = Sihl__user.User
module View = Sihl__view.View

let if_debug m h = if Config.debug () then m h else h
