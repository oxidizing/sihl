module Sql = struct
  module User = struct
    let get_all =
      let open Model.User in
      [%rapper
        get_many
          {sql|
        SELECT 
          uuid as @string{id}, 
          @string{email}, 
          @string{username}, 
          @string{password},
          @string{name},
          @string?{phone},
          @string{status},
          @bool{admin},
          @bool{confirmed}
        FROM users_users
        |sql}
          record_out]

    let get =
      let open Model.User in
      [%rapper
        get_one
          {sql|
        SELECT 
          uuid as @string{id}, 
          @string{email}, 
          @string{username}, 
          @string{password},
          @string{name},
          @string?{phone},
          @string{status},
          @bool{admin},
          @bool{confirmed}
        FROM users_users
        WHERE users_users.id = %string{id}
        |sql}
          record_out]

    let get_by_email =
      let open Model.User in
      [%rapper
        get_one
          {sql|
        SELECT 
          uuid as @string{id}, 
          @string{email}, 
          @string{username}, 
          @string{password},
          @string{name},
          @string?{phone},
          @string{status},
          @bool{admin},
          @bool{confirmed}
        FROM users_users
        WHERE users_users.email = %string{email}
        |sql}
          record_out]

    let insert =
      let open Model.User in
      [%rapper
        execute
          {sql|
        INSERT INTO users_users (
          uuid, 
          email, 
          username, 
          password,
          name,
          phone,
          status,
          admin,
          confirmed
        ) VALUES (
          %string{id}, 
          %string{email}, 
          %string{username}, 
          %string{password},
          %string{name},
          %string?{phone},
          %string{status},
          %bool{admin},
          %bool{confirmed}
        )
        |sql}
          record_in]

    let update =
      let open Model.User in
      [%rapper
        execute
          {sql|
        UPDATE users_users
        SET 
          uuid = %string{id}, 
          email = %string{email}, 
          username = %string{username}, 
          password = %string{password},
          name = %string{name},
          phone = %string?{phone},
          status = %string{status},
          admin = %bool{admin},
          confirmed = %bool{confirmed}
        |sql}
          record_in]

    let clean =
      [%rapper execute {sql|
        TRUNCATE TABLE users_users;
        |sql}]
  end

  module Token = struct
    let get =
      let open Model.Token in
      [%rapper
        get_one
          {sql|
        SELECT 
          uuid as @string{id}, 
          @string{value},
          @string{kind},
          @string{token_user},
          @string{status}
        FROM users_tokens
        WHERE users_tokens.value = %string{value}
        |sql}
          record_out]

    let insert =
      let open Model.Token in
      [%rapper
        execute
          {sql|
        INSERT INTO users_tokens (
          uuid, 
          value,
          kind,
          token_user,
          status
        ) VALUES (
          %string{id}, 
          %string{value},
          %string{kind},
          %string{token_user},
          %string{status}
        )
        |sql}
          record_in]

    let update =
      let open Model.Token in
      [%rapper
        execute
          {sql|
        UPDATE users_tokens 
        SET 
          uuid = %string{id}, 
          value = %string{value},
          kind = %string{kind},
          token_user = %string{token_user},
          status = %string{status}
        |sql}
          record_in]

    let delete_by_user =
      [%rapper
        execute
          {sql|
        DELETE FROM users_tokens 
        WHERE users_tokens.id = %string{id}
        |sql}]

    let clean =
      [%rapper execute {sql|
        TRUNCATE TABLE users_tokens;
        |sql}]
  end
end

module User = struct
  let get_all req = Sihl_core.Db.query_db (fun c -> Sql.User.get_all c ()) req

  let get req ~id = Sihl_core.Db.query_db (fun c -> Sql.User.get c ~id) req

  let get_by_email req ~email =
    Sihl_core.Db.query_db (fun c -> Sql.User.get_by_email c ~email) req

  let insert req user =
    Sihl_core.Db.query_db (fun c -> Sql.User.insert c user) req

  let update req user =
    Sihl_core.Db.query_db (fun c -> Sql.User.update c user) req

  let clean req = Sihl_core.Db.query_db (fun c -> Sql.User.clean c ()) req
end

module Token = struct
  let get req ~value =
    Sihl_core.Db.query_db (fun c -> Sql.Token.get c ~value) req

  let delete_by_user req ~id =
    Sihl_core.Db.query_db (fun c -> Sql.Token.delete_by_user c ~id) req

  let insert req token =
    Sihl_core.Db.query_db (fun c -> Sql.Token.insert c token) req

  let update req token =
    Sihl_core.Db.query_db (fun c -> Sql.Token.update c token) req

  let clean req = Sihl_core.Db.query_db (fun c -> Sql.Token.clean c ()) req
end
