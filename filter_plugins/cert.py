import os
import unittest


class Cert:
    @staticmethod
    def name(dehydrated, domain):
        if 'domains' not in dehydrated.keys():
            return None

        for crt_name, crt_domains in dehydrated['domains'].items():
            if domain == crt_name or domain in crt_domains:
                return crt_name

            for crt_domain in [crt_name] + crt_domains:
                if crt_domain.startswith('*.') and crt_domain[2:] == domain[domain.find('.') + 1:]:
                    return crt_name

        return None

    @staticmethod
    def exists(dehydrated, domain):
        return True if Cert.name(dehydrated, domain) else False

    @staticmethod
    def file(dehydrated, domain, file):
        name = Cert.name(dehydrated, domain)
        if not name:
            return None

        return os.path.join(dehydrated['prefix']['certs'], name, file)

    @staticmethod
    def cert(dehydrated, domain):
        return Cert.file(dehydrated, domain, 'cert.pem')

    @staticmethod
    def chain(dehydrated, domain):
        return Cert.file(dehydrated, domain, 'chain.pem')

    @staticmethod
    def fullchain(dehydrated, domain):
        return Cert.file(dehydrated, domain, 'fullchain.pem')

    @staticmethod
    def fullchainandprivkey(dehydrated, domain):
        return Cert.file(dehydrated, domain, 'fullchainandprivkey.pem')

    @staticmethod
    def privkey(dehydrated, domain):
        return Cert.file(dehydrated, domain, 'privkey.pem')


class CertTest(unittest.TestCase):
    def test_name(self):
        self.assertEqual(
            Cert.name({'domains': {
                'foo.com': ['foo.net', 'foo.org', 'foo.info'],
                'bar.com': ['bar.net', 'bar.org', 'bar.info'],
                'baz.com': ['baz.net', 'baz.org', 'baz.info'],
            }}, 'bar.org'),
            'bar.com',
        )
        self.assertEqual(
            Cert.name(
                {'domains': {
                    'foo.com': ['foo.net', 'foo.org', 'foo.info'],
                    'bar.com': ['bar.net', 'bar.org', 'bar.info'],
                    'baz.com': ['baz.net', 'baz.org', 'baz.info'],
                }}, 'baz.com'),
            'baz.com',
        )
        self.assertEqual(
            Cert.name({'domains': {
                '*.*.example.com': ['example.com'],
                '*.example.com': ['example.com'],
                'example.net': ['*.example.net'],
            }}, 'test.example.com'),
            '*.example.com',
        )
        self.assertEqual(
            Cert.name({'domains': {
                '*.*.example.com': ['example.com'],
                '*.example.net': ['example.net'],
                'example.com': ['*.example.com'],
            }}, 'test.example.com'),
            'example.com',
        )

    def test_exists(self):
        self.assertEqual(
            Cert.exists({'domains': {'example.com': ['example.net', 'example.org']}}, 'example.net'),
            True,
        )

    def test_fullchain(self):
        self.assertEqual(
            Cert.fullchain(
                {'domains': {'example.com': ['example.net', 'example.org']},
                 'prefix': {'certs': '/usr/local/etc/ssl/certs'}}, 'example.net'),
            '/usr/local/etc/ssl/certs/example.com/fullchain.pem',
        )


class FilterModule(object):
    def filters(self):
        return {
            'cert_name': Cert.name,
            'cert_exists': Cert.exists,
            'cert_file': Cert.file,
            'cert_cert': Cert.cert,
            'cert_chain': Cert.chain,
            'cert_fullchain': Cert.fullchain,
            'cert_fullchainandprivkey': Cert.fullchainandprivkey,
            'cert_privkey': Cert.privkey,
        }


if __name__ == '__main__':
    unittest.main()
