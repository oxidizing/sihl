open Base

let externalize
    ?(prefix = Configuration.read_string_default ~default:"" "PREFIX_PATH") path
    =
  path |> String.split ~on:'/' |> List.cons prefix |> String.concat ~sep:"/"
  |> String.substr_replace_all ~pattern:"//" ~with_:"/"
