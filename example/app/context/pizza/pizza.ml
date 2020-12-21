let cleaner = Repo.clean

let create name ingredients =
  let pizza = Model.create name ingredients in
  Repo.insert_pizza pizza
;;
