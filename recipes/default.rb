#
# Cookbook Name:: sssd
# Recipe:: default
#
# Copyright (C) 2014 Char Software, Inc.
#
# All rights reserved - see LICENSE
#

if [['realm', 'databag'],['realm', 'databag_item'],['ldap', 'databag'],['ldap', 'databag_item']].any? {|key, subkey| node['sssd'][key][subkey].nil? }
  Chef::Application.fatal!("You must setup the appropriate databag attributes!")
end

# These are created with:
#   openssl rand -base64 512 | tr -d '\r\n' > test/support/encrypted_data_bag_secret
#   knife solo data bag create sssd_credentials realm -c .chef/solo.rb
#   knife solo data bag create sssd_credentails ldap -c .chef/solo.rb
realm_databag_contents = Chef::EncryptedDataBagItem.load(node['sssd']['realm']['databag'],node['sssd']['realm']['databag_item'])
ldap_databag_contents = Chef::EncryptedDataBagItem.load(node['sssd']['ldap']['databag'],node['sssd']['ldap']['databag_item'])

include_recipe 'apt::default'
include_recipe 'resolver::default'

package 'expect'
package 'sssd'
package 'sssd-ad'
package 'sssd-ad-common'
package 'sssd-tools'
package 'realmd'
package 'samba-common'
package 'samba-libs'
package 'samba-common-bin'

# The sleep 10 is necessary to give the "realm" command enough time before replacing sssd.conf and restarting.
# Took me a while to figure out :( Pull requests welcome for a better fix!
bash 'join_domain' do
  user 'root'
  code <<-EOF
  /usr/bin/expect -c 'spawn realm join -U #{realm_databag_contents['user']} #{node['resolver']['search']}
  expect "Password for #{realm_databag_contents['user']}: "
  send "#{realm_databag_contents['password']}\r"
  expect eof'
  sleep 10
  EOF
  not_if "realm list | egrep '^#{node['resolver']['search']}'"
  notifies :restart, 'service[sssd]'
end

template '/etc/sssd/sssd.conf' do
  source 'sssd.conf.erb'
  owner 'root'
  group 'root'
  mode '0600'
  notifies :restart, 'service[sssd]'
  variables({
    :domain => node['resolver']['search'],
    :realm => node['resolver']['search'].upcase,
    :ldap_suffix => node['resolver']['search'].split('.').map { |s| "dc=#{s}" }.join(','),
    :ldap_user => ldap_databag_contents['user'],
    :ldap_password => ldap_databag_contents['password']
  })
end

service 'sssd' do
  supports :status => true, :restart => true, :reload => true
  action [:enable, :start]
  provider Chef::Provider::Service::Upstart
end
