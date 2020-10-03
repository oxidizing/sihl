(** This is the core of Sihl, every other component builds on top of it.

    A module to manage CLI commands, configurations, service lifecycles, the request
    context, and Sihl apps. *)

module Container = Container
module Ctx = Ctx
module App = App
module Configuration = Configuration
module Command = Command
module Log = Log
