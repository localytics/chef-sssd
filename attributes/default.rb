# The /etc/resolv.conf nameserver IP address (or addresses) (IE: [ '192.168.1.100', '192.168.1.101' ])
# These must be able to resolve your AD domain, and *can* be set to Simple AD server IPs.
default['resolver']['nameservers'] = nil

# The AD domain (ie: example.com)
default['resolver']['search'] = nil

# Databag: realm username/password, for joining the domain
# {
#   "id": "realm",
#   "user": "example",
#   "password": "password"
# }
default['sssd']['realm']['databag'] = nil
default['sssd']['realm']['databag_item'] = nil

# Databag: ldap username/password, for accessing sudo information
# {
#   "id": "ldap",
#   "user": "example",
#   "password": "password"
# }
default['sssd']['ldap']['databag'] = nil
default['sssd']['ldap']['databag_item'] = nil

# A test user in your AD directory, used in serverspec tests only.
# The user should have:
#   * some sudo privileges to pass the sudo test
#   * an ssh key to verify LDAP ssh keys are functioning
default['sssd']['test_user'] = 'Guest'
