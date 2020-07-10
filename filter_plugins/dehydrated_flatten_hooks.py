def dehydrated_flatten_hooks(dehydrated_hooks):
    flattened_hooks = []
    for hook_type, hooks in dehydrated_hooks.items():
        for hook_name, hook_script in hooks.items():
            if not hook_script:
                continue
            flattened_hooks.append({
                'hook': hook_type,
                'name': hook_name,
                'script': hook_script,
            })
    return flattened_hooks


def dehydrated_flatten_hooks_test():
    actual = dehydrated_flatten_hooks({
        'deploy_cert': {
            'foo': 'bar',
            'baz': '',
        },
        'deploy_ocsp': {
            'foo': 'foo',
        }
    })
    expected = [
        {
            'hook': 'deploy_cert',
            'name': 'foo',
            'script': 'bar',
        },
        {
            'hook': 'deploy_ocsp',
            'name': 'foo',
            'script': 'foo',
        },
    ]
    print(actual == expected)


class FilterModule(object):
    def filters(self):
      return {
      'dehydrated_flatten_hooks': dehydrated_flatten_hooks,
    }


if __name__ == '__main__':
    dehydrated_flatten_hooks_test()
