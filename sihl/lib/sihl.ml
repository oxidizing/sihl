module Command = Sihl__command.Command
module Config = Sihl__config.Config
module Model = Sihl__model.Model
module User = Sihl__user.User
module Form = Sihl__form.Form
module View = Sihl__view.View
module Query = Sihl__query.Query
module Migration = Sihl__migration.Migration
module Test = Sihl__test.Test

let if_debug m h = if Config.debug () then m h else h
