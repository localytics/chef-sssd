# Package lists
case node['platform']
when 'ubuntu'
  # We install samba-common, samba-libs, and samba-common-bin ahead of time due to:
  #   https://bugs.launchpad.net/ubuntu/+source/realmd/+bug/1333694
  default['sssd']['packages'] = %w(expect sssd sssd-ad sssd-ad-common sssd-tools adcli realmd samba-common samba-libs samba-common-bin)
when 'centos'
  # CentOS 7 supports realmd, but 6 does not. We'll call adcli directly until RHEL 7.
  default['sssd']['packages'] = %w(expect sssd sssd-ad sssd-common sssd-tools adcli authconfig krb5-workstation)
end

# The /etc/resolv.conf nameserver IP address (or addresses) (IE: [ '192.168.1.100', '192.168.1.101' ]) and search domain.
# These settings must allow resolution of your AD domain, and can be set to either Simple AD server IPs or isolated DNS servers.
default['resolver']['nameservers'] = nil
default['resolver']['search'] = nil

# The directory name, as specified in "Directory Details" in the AWS console (may match ['resolver']['search'] above)
default['sssd']['directory_name'] = nil

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
