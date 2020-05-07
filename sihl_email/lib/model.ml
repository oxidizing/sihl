module Template = struct
  type t = { id : string; label : string; value : string; status : string }

  let value template = template.value

  let create ~label ~value = { id = "TODO"; label; value; status = "active" }
end
