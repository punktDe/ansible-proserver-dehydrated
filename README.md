<!-- BEGIN_ANSIBLE_DOCS -->
<!--
Do not edit README.md directly!

This file is generated automatically by aar-doc and will be overwritten.

Please edit meta/argument_specs.yml instead.
-->
# ansible-proserver-dehydrated

dehydrated role for Proserver

## Supported Operating Systems

- Debian 12
- Ubuntu 24.04, 22.04
- FreeBSD [Proserver](https://infrastructure.punkt.de/de/produkte/proserver.html)

## Role Arguments



Configures dehydrated ACME client for automatic SSL certificate management

Supports Let's Encrypt and other ACME-compatible CAs

Handles domain certificate generation and renewal

Supports ACME-DNS and ACME-Cache for DNS-01 challenges

#### Options for `dehydrated`

|Option|Description|Type|Required|Default|
|---|---|---|---|---|
| `prefix` | Path prefixes for different components | dict of 'prefix' options | no |  |
| `config` | Dehydrated configuration parameters | dict of 'config' options | no |  |
| `domains` | Domains to request certificates for. Key is the Common Name, value is list of Subject Alternative Names. | dict | no | "{} Example: vpro0000.proserver.punkt.de: [] punkt.de: ['www.punkt.de', 'proserver.punkt.de']" |
| `acme_dns` | ACME-DNS configuration for DNS-01 challenges. Maps domain names to acme-dns server configuration. | dict of 'acme_dns' options | no | {} |
| `acme_cache` | ACME-Cache configuration for DNS-01 challenges. Maps domain names to acme-cache server configuration. | dict of 'acme_cache' options | no | {} |
| `command` | Command to run dehydrated (cron job or systemd service). Should start the dehydrated certificate renewal process. | str | no | systemctl start dehydrated (Linux) or custom cron (other) |
| `httpd_service` | HTTP service configuration for certificate deployment | dict of 'httpd_service' options | no |  |
| `hooks` | Custom hook scripts for certificate lifecycle events | dict of 'hooks' options | no | Empty dict with all hook types |
| `systemd` | Systemd timer configuration | dict of 'systemd' options | no |  |
| `disable_renewal` | Disable automatic certificate renewal | bool | no | no |
| `do_not_renew` | Domains to exclude from renewal | dict | no | "{}" |
| `provide_dummy_cert` | Provide dummy self-signed certificates initially | bool | no | yes |
| `dummy_cert` | PEM-encoded self-signed certificate content (for initial use before ACME issuance) | str | no | Built-in self-signed certificate |
| `dummy_key` | PEM-encoded private key for dummy certificate | str | no | Built-in private key |

#### Options for `dehydrated.prefix`

|Option|Description|Type|Required|Default|
|---|---|---|---|---|
| `bin` | Path to dehydrated binary directory | str | no | /usr/bin (Linux) or /usr/local/bin (other) |
| `certs` | Path to store certificates | str | no | /var/lib/dehydrated/certs (Linux) or /usr/local/etc/ssl/certs (other) |
| `config` | Path to dehydrated configuration directory | str | no | /etc/dehydrated (Linux) or /usr/local/etc/dehydrated (other) |

#### Options for `dehydrated.config`

|Option|Description|Type|Required|Default|
|---|---|---|---|---|
| `CA` | ACME server directory URL | str | no | https://acme-v02.api.letsencrypt.org/directory |
| `WELLKNOWN` | Path to ACME challenge directory (http-01) | str | no | /var/lib/dehydrated/acme-challenges (Linux) or /var/www/letsencrypt (other) |
| `HOOK` | Path to dehydrated hook script | str | no | /etc/dehydrated/hook.sh (Linux) or /usr/local/etc/dehydrated/hook.sh (other) |

#### Options for `dehydrated.acme_dns`

|Option|Description|Type|Required|Default|
|---|---|---|---|---|
| `<domain_name>` | Configuration for specific domain | dict of '<domain_name>' options | no |  |

#### Options for `dehydrated.acme_dns.<domain_name>`

|Option|Description|Type|Required|Default|
|---|---|---|---|---|
| `host` | ACME-DNS server hostname | str | no |  |
| `public_key` | Public SSH host key of ACME-DNS server | str | no |  |

#### Options for `dehydrated.acme_cache`

|Option|Description|Type|Required|Default|
|---|---|---|---|---|
| `<domain_name>` | Configuration for specific domain | dict of '<domain_name>' options | no |  |

#### Options for `dehydrated.acme_cache.<domain_name>`

|Option|Description|Type|Required|Default|
|---|---|---|---|---|
| `host` | ACME-Cache server hostname | str | no |  |
| `public_key` | Public SSH host key of ACME-Cache server | str | no |  |

#### Options for `dehydrated.httpd_service`

|Option|Description|Type|Required|Default|
|---|---|---|---|---|
| `name` | Name of HTTP service to reload after certificate update. Automatically determined based on ansible_system and group membership. | str | no | apache2 (Linux+Apache), apache24 (BSD+Apache), nginx (other) |
| `state` | State action for HTTP service after certificate update | str | no | reloaded |

#### Options for `dehydrated.hooks`

|Option|Description|Type|Required|Default|
|---|---|---|---|---|
| `deploy_challenge` | Scripts to run when deploying challenge | dict | no | "{}" |
| `clean_challenge` | Scripts to run when cleaning challenge | dict | no | "{}" |
| `sync_cert` | Scripts to run when syncing certificate | dict | no | "{}" |
| `deploy_cert` | Scripts to run when deploying certificate | dict | no | "{}" |
| `deploy_ocsp` | Scripts to run when deploying OCSP response | dict | no | "{}" |
| `unchanged_cert` | Scripts to run when certificate is unchanged | dict | no | "{}" |
| `invalid_challenge` | Scripts to run on invalid challenge | dict | no | "{}" |
| `request_failure` | Scripts to run on request failure | dict | no | "{}" |
| `generate_csr` | Scripts to run when generating CSR | dict | no | "{}" |
| `startup` | Scripts to run on startup | dict | no | "{}" |
| `exit` | Scripts to run on exit | dict | no | "{}" |

#### Options for `dehydrated.systemd`

|Option|Description|Type|Required|Default|
|---|---|---|---|---|
| `timer` | Systemd OnCalendar specification for certificate renewal | str | no | *-*-* 00:00:00 with RandomizedDelaySec=6h |

## Dependencies
None.

## Installation
Add this role to the requirements.yml of your playbook as follows:
```yaml
roles:
  - name: ansible-proserver-dehydrated
    src: https://github.com/punktDe/ansible-proserver-dehydrated
```

Afterwards, install the role by running `ansible-galaxy install -r requirements.yml`

## Example Playbook

```yaml
- hosts: all
  roles:
    - name: dehydrated
```

<!-- END_ANSIBLE_DOCS -->
