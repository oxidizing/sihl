module Command = Sihl__command.Command
module Config = Sihl__config.Config
module Form = Sihl__form.Form
module Migration = Sihl__migration.Migration
module Model = Sihl__model.Model
module Query = Sihl__query.Query
module Test = Sihl__test.Test
module User = Sihl__user.User
module View = Sihl__view.View

let run f =
  Command.register (Command.start_command f);
  Command.run ()
;;

let router routes =
  let if_debug m h = if Config.debug () then m h else h in
  let routes =
    if Config.debug () then routes @ [ Dream_livereload.route () ] else routes
  in
  let routes =
    routes
    @ [ Dream.get (Filename.concat (Config.static_url ()) "/**")
        @@ Dream.static (Config.static_dir ())
      ]
  in
  Dream.logger
  @@ if_debug (Dream_livereload.inject_script ())
  @@ Dream.router routes
;;
