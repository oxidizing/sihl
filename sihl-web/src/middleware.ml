module Csrf = Middleware_csrf
module Flash = Middleware_flash
module Static = Middleware_static
module Session = Middleware_session
module Authn = Middleware_authn
module User = Middleware_user
module Form_parser = Form_parser

let static = Middleware_static.m
