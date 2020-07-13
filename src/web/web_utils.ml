open Base

let externalize ?(prefix = Config.read_string_default ~default:"" "URL_PREFIX")
    path =
  path |> String.split ~on:'/' |> List.cons prefix |> String.concat ~sep:"/"
  |> String.substr_replace_all ~pattern:"//" ~with_:"/"
