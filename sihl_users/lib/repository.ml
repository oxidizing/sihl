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
      [%rapper
        execute {sql|
        TRUNCATE TABLE users_users CASCADE;
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
      [%rapper
        execute {sql|
        TRUNCATE TABLE users_tokens CASCADE;
        |sql}]
  end
end

module User = struct
  let get_all connection = Sql.User.get_all connection ()

  let get ~id connection = Sql.User.get connection ~id

  let get_by_email ~email connection = Sql.User.get_by_email connection ~email

  let insert user connection = Sql.User.insert connection user

  let update user connection = Sql.User.update connection user

  let clean connection = Sql.User.clean connection ()
end

module Token = struct
  let get ~value connection = Sql.Token.get connection ~value

  let delete_by_user ~id connection = Sql.Token.delete_by_user connection ~id

  let insert token connection = Sql.Token.insert connection token

  let update token connection = Sql.Token.update connection token

  let clean connection = Sql.Token.clean connection ()
end
