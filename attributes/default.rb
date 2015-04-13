case node['platform']
when 'ubuntu'
  default['sssd']['packages'] = %w(expect sssd sssd-ad sssd-ad-common sssd-tools adcli krb5-user)
when 'centos'
  default['sssd']['packages'] = %w(expect sssd sssd-ad sssd-common sssd-tools adcli authconfig krb5-workstation)
end

default['sssd']['computer_name'] = nil
default['sssd']['directory_name'] = nil

# {
#   "id": "realm",
#   "username": "administrator",
#   "password": "password"
# }
default['sssd']['realm']['databag'] = nil
default['sssd']['realm']['databag_item'] = nil
