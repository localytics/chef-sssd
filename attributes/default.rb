# The AD host IP address (or addresses) (IE: [ '192.168.1.100', '192.168.1.101' ])
default['resolver']['nameservers'] = nil

# The AD domain (ie: example.com)
default['resolver']['search'] = nil

# The realm join username (an account that can be used to join the host to the domain)
default['sssd']['realm']['user'] = nil

# The realm join password (the password for the account above)
# This should likely come from a databag (or other means) via a wrapper cookbook!
default['sssd']['realm']['password'] = nil

# The ldap sssd username (optional username to use to access data via the ldap sssd provider)
default['sssd']['ldap']['user'] = nil

# The ldap sssd password (the password for the account above)
# This should likely come from a databag (or other means) via a wrapper cookbook!
default['sssd']['ldap']['password'] = nil
