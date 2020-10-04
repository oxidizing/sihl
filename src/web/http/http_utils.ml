open Base

let externalize ?prefix path =
  let prefix =
    Option.value
      (Option.first_some prefix (Core.Configuration.read_string "PREFIX_PATH"))
      ~default:""
  in
  path
  |> String.split ~on:'/'
  |> List.cons prefix
  |> String.concat ~sep:"/"
  |> String.substr_replace_all ~pattern:"//" ~with_:"/"
;;
