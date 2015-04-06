#
# Cookbook Name:: sssd
# Recipe:: default
#
# Copyright (C) 2015 Localytics
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

if [['realm', 'databag'],['realm', 'databag_item'],['ldap', 'databag'],['ldap', 'databag_item']].any? {|key, subkey| node['sssd'][key][subkey].nil? }
  Chef::Application.fatal!("You must setup the appropriate databag attributes!")
end

# These are created with:
#   openssl rand -base64 512 | tr -d '\r\n' > test/support/encrypted_data_bag_secret
#   knife solo data bag create sssd_credentials realm -c .chef/solo.rb
#   knife solo data bag create sssd_credentials ldap -c .chef/solo.rb
realm_databag_contents = Chef::EncryptedDataBagItem.load(node['sssd']['realm']['databag'],node['sssd']['realm']['databag_item'])
ldap_databag_contents = Chef::EncryptedDataBagItem.load(node['sssd']['ldap']['databag'],node['sssd']['ldap']['databag_item'])

case node['platform']
when 'ubuntu'
  include_recipe 'apt'
when 'centos'
  include_recipe 'yum'
  include_recipe 'yum-epel'
end
include_recipe 'resolver::default'

node['sssd']['packages'].each do |pkg|
  package(pkg)
end

case node['platform']
when 'ubuntu'
  bash 'join_domain' do
    user 'root'
    code <<-EOF
    /usr/bin/expect -c 'spawn realm join -U #{realm_databag_contents['user']} #{node['resolver']['search']}
    expect "Password for #{realm_databag_contents['user']}: "
    send "#{realm_databag_contents['password']}\r"
    expect eof'
    EOF
    only_if "realm discover #{node['sssd']['directory_name']} | grep 'configured: no'"
  end
when 'centos'
  bash 'join_domain' do
    user 'root'
    code <<-EOF
    /usr/bin/expect -c 'spawn adcli join -U #{realm_databag_contents['user']} #{node['resolver']['search']}
    expect "Password for #{realm_databag_contents['user']}: "
    send "#{realm_databag_contents['password']}\r"
    expect eof'
    EOF
    not_if "klist -k | grep -i '@#{node['sssd']['directory_name']}'"
  end
end

template '/etc/sssd/sssd.conf' do
  source 'sssd.conf.erb'
  owner 'root'
  group 'root'
  mode '0600'
  notifies :restart, 'service[sssd]'
  variables({
    :domain => node['sssd']['directory_name'],
    :realm => node['sssd']['directory_name'].upcase,
    :ldap_suffix => node['sssd']['directory_name'].split('.').map { |s| "dc=#{s}" }.join(','),
    :ldap_user => ldap_databag_contents['user'],
    :ldap_password => ldap_databag_contents['password']
  })
end

# Since there's no realm in CentOS, we have to manually enable SSSD
if node['platform'] == 'centos'
  bash 'enable_sssd' do
    user 'root'
    code <<-EOF
    authconfig --enablesssd --enablesssdauth --update
    echo 'sudoers:    files sss' >> /etc/nsswitch.conf
    EOF
    not_if "grep -i 'sudoers:    files sss' /etc/nsswitch.conf"
  end
end

service 'sssd' do
  supports :status => true, :restart => true, :reload => true
  action [:enable, :start]
  provider Chef::Provider::Service::Upstart if node['platform'] == 'ubuntu'
end
