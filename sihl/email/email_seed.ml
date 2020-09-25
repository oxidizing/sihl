(* let add_confirmation_template =
   *       Data.Migration.create_step ~label:"create default email templates"
   *         {sql|
   *         INSERT INTO email_templates (
   *           uuid,
   *           label,
   *           content_text,
   *           content_html,
   *           status
   *         ) VALUES (
   *           'fb7aec3f-2178-4166-beb4-79a3a663e093',
   *           'registration_confirmation',
   *           'Hi, \n\n Thanks for signing up. \n\n Please go to this URL to confirm your email address: {base_url}/app/confirm-email?token={token} \n\n Best, \n Josef',
   *           '',
   *           'active'
   *         )
   * |sql}
   *
   *     let add_password_reset_template =
   *       Data.Migration.create_step ~label:"create default email templates"
   *         {sql|
   *         INSERT INTO email_templates (
   *           uuid,
   *           label,
   *           content_text,
   *           content_html,
   *           status
   *         ) VALUES (
   *           'fb7aec3f-2178-4166-beb4-79a3a663e092',
   *           'registration_confirmation',
   *           'Hi, \n\n You requested to reset your password. \n\n Please go to this URL to reset your password: {base_url}/app/password-reset?token={token} \n\n Best, \n Josef',
   *           '',
   *           'active'
   *         )
   * |sql} *)
