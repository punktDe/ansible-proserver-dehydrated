import os


def cert_name(dehydrated, domain):
    if 'domains' not in dehydrated.keys():
        return None

    for crt_name, crt_domains in dehydrated['domains'].items():
        if domain == crt_name or domain in crt_domains:
            return crt_name

        for crt_domain in [crt_name] + crt_domains:
            if crt_domain.startswith('*.') and crt_domain[2:] == domain[domain.find('.') + 1:]:
                return crt_name

    return None


def cert_exists(dehydrated, domain):
    return True if cert_name(dehydrated, domain) else False


def cert_file(dehydrated, domain, file):
    name = cert_name(dehydrated, domain)
    if not name:
        return None

    return os.path.join(dehydrated['prefix']['certs'], name, file)


def cert_cert(dehydrated, domain):
    return cert_file(dehydrated, domain, 'cert.pem')


def cert_chain(dehydrated, domain):
    return cert_file(dehydrated, domain, 'chain.pem')


def cert_fullchain(dehydrated, domain):
    return cert_file(dehydrated, domain, 'fullchain.pem')


def cert_privkey(dehydrated, domain):
    return cert_file(dehydrated, domain, 'privkey.pem')


def cert_name_test():
    result = cert_name({'domains': {
        'foo.com': ['foo.net', 'foo.org', 'foo.info'],
        'bar.com': ['bar.net', 'bar.org', 'bar.info'],
        'baz.com': ['baz.net', 'baz.org', 'baz.info'],
    }}, 'bar.org')
    print(result, result == 'bar.com')

    result = cert_name({'domains': {
        'foo.com': ['foo.net', 'foo.org', 'foo.info'],
        'bar.com': ['bar.net', 'bar.org', 'bar.info'],
        'baz.com': ['baz.net', 'baz.org', 'baz.info'],
    }}, 'baz.com')
    print(result, result == 'baz.com')

    result = cert_name({'domains': {
        '*.*.example.com': ['example.com'],
        '*.example.com': ['example.com'],
        'example.net': ['*.example.net'],
    }}, 'test.example.com')
    print(result, result == '*.example.com')

    result = cert_name({'domains': {
        '*.*.example.com': ['example.com'],
        '*.example.net': ['example.net'],
        'example.com': ['*.example.com'],
    }}, 'test.example.com')
    print(result, result == 'example.com')


def cert_exists_test():
    result = cert_exists(
        {'domains': {'example.com': ['example.net', 'example.org']}}, 'example.net')
    print(result, result == True)


def cert_fullchain_test():
    result = cert_fullchain(
        {'domains': {'example.com': ['example.net', 'example.org']},
         'prefix': {'certs': '/usr/local/etc/ssl/certs'}}, 'example.net')
    print(result, result == '/usr/local/etc/ssl/certs/example.com/fullchain.pem')


class FilterModule(object):
    def filters(self):
        return {
            'cert_name': cert_name,
            'cert_exists': cert_exists,
            'cert_file': cert_file,
            'cert_cert': cert_cert,
            'cert_chain': cert_chain,
            'cert_fullchain': cert_fullchain,
            'cert_privkey': cert_privkey,
        }


if __name__ == '__main__':
    cert_name_test()
    cert_exists_test()
    cert_fullchain_test()
