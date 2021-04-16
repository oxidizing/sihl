# {{ project_name }}

{%- if ci_cd == 'Github' %}

[![Actions Status](https://github.com/{{ github_username }}/{{ project_slug }}/workflows/CI/badge.svg)](https://github.com/{{ github_username }}/{{ project_slug }}/actions)
{%- endif %}

{%- if project_description %}

{{ project_description }}
{%- endif %}

## Contributing

Take a look at our [Contributing Guide](CONTRIBUTING.md).
