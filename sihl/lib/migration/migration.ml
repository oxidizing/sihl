include Migration_dsl

let postgresql_updated_at_trigger =
  {sql|
   CREATE OR REPLACE FUNCTION update_updated_at_column()
   RETURNS TRIGGER AS $$
   BEGIN
     NEW.updated_at = now();
     RETURN NEW;
   END;
$$ language 'plpgsql';
|sql}
;;
