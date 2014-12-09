#
# Cookbook Name:: sssd
# Recipe:: default
#
# Copyright (C) 2014 Char Software, Inc.
#
# All rights reserved - see LICENSE
#

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
  /usr/bin/expect -c 'spawn realm join -U #{node['sssd']['realm']['user']} #{node['resolver']['search']}
  expect "Password for #{node['sssd']['realm']['user']}: "
  send "#{node['sssd']['realm']['password']}\r"
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
    :ldap_user => node['sssd']['ldap']['user'],
    :ldap_password => node['sssd']['ldap']['password']
  })
end

service 'sssd' do
  supports :status => true, :restart => true, :reload => true
  action [:enable, :start]
  provider Chef::Provider::Service::Upstart
end
