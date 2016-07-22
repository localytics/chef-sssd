case node['platform']
when 'ubuntu'
  default['sssd']['packages'] = %w(sssd sssd-ad sssd-ad-common sssd-tools adcli krb5-user)
when 'centos'
  default['sssd']['packages'] = %w(sssd sssd-ad sssd-common sssd-tools authconfig krb5-workstation)
end

default['sssd']['join_domain'] = true
default['sssd']['enumerate'] = false
default['sssd']['computer_name'] = nil
default['sssd']['directory_name'] = nil
default['sssd']['use_encrypted_data_bag_secret'] = false

# {
#   "id": "realm",
#   "username": "administrator",
#   "password": "password"
# }
default['sssd']['realm']['databag'] = 'sssd_credentials'
default['sssd']['realm']['databag_item'] = 'realm'

default['sssd']['adcli']['rpm'] = 'adcli-0.8.0-1.el6.x86_64.rpm'
default['sssd']['adcli']['rpm_source'] = "https://s3.amazonaws.com/public.localytics/artifacts/#{node['sssd']['adcli']['rpm']}"

default['sssd']['service_actions'] = [:enable]
