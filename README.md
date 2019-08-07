# [proserver-ansible-dehydrated](https://github.com/punktDe/proserver-ansible-dehydrated)

Ansible role to configure dehydrated on a proServer.

## Requirements

- A proServer
- Ansible >=2.4.0
- Ansible option `hash_behaviour` set to `merge`

## Configuration

**1)** Add this role as dependency to your role (e.g. `roles/nginx/meta/main.yaml`).
You could add this repository as submodule to your Ansible project's Git repository.

```
git submodule add https://github.com/punktDe/proserver-ansible-dehydrated.git roles/dehydrated
```

```yaml
---
dependencies:
  - role: dehydrated
```

**2)** You can find a list of variables and their default values in `defaults/main.yaml`.
Override them as you wish.

```yaml
---
dependencies:
  - { role: dehydrated, dehydrated: { provide_dummy_cert: yes, httpd_service: { name: nginx, state: reloaded } } }
```

**3)** Configure domains (e.g. in host vars). This example would result in two certificates being generated: one with `vpro0000.proserver.punkt.de` as Common Name and one with `punkt.de` as Common Name and `www.punkt.de` and `proserver.punkt.de` as Subject Alternative Name.

```yaml
---
dehydrated:
  domains:
    vpro0000.proserver.punkt.de: []
    punkt.de: ['www.punkt.de', 'proserver.punkt.de']
```

The certificate will be saved to `/usr/local/etc/ssl/certs/{{ domain_name }}/`.
