type key_value = string * string

type t = {
  development : key_value list;
  test : key_value list;
  production : key_value list;
}

let production setting = setting.production

let development setting = setting.development

let test setting = setting.test

let create ~development ~test ~production = { development; test; production }
