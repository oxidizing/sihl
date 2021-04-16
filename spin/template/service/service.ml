{% if database == 'PostgreSql' %}
module Migration = Sihl.Database.Migration.PostgreSql
{% endif %}
{% if database == 'MariaDb' %}
module Migration = Sihl.Database.Migration.MariaDb
{% endif %}
