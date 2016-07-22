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

if node['sssd']['directory_name'].nil?
  Chef::Application.fatal!('You must set the directory name!')
end

if node['sssd']['computer_name'].nil?
  # We must limit the computer name to 15 characters, to avoid truncating:
  #   https://bugs.freedesktop.org/show_bug.cgi?id=69016
  computer_name = node['fqdn'][0..14]
else
  computer_name = node['sssd']['computer_name']
end

case node['platform']
when 'centos'
  include_recipe 'yum-epel'
  include_recipe 'sssd::adcli'
end

node['sssd']['packages'].each do |pkg|
  package(pkg)
end

if node['sssd']['join_domain'] == true
  # We enforce encrypted data bag here because mostly anything else (environment attribute?) is scary
  begin
    if node['sssd']['encrypted_data_bag_secret']
      realm_databag_contents = Chef::EncryptedDataBagItem.load(node['sssd']['realm']['databag'],node['sssd']['realm']['databag_item'],node['sssd']['encrypted_data_bag_secret'])
    else
      realm_databag_contents = Chef::EncryptedDataBagItem.load(node['sssd']['realm']['databag'],node['sssd']['realm']['databag_item'])
    end
  rescue
    Chef::Application.fatal!('Unable to access the encrypted data bag for domain credentials, ensure encrypted_data_bag_secret is available!')
  end

  # The ideal here (and future PR) is "realm join", but for now, we use adcli due to:
  #   CentOS 6: realm is only available in RHEL/CentOS 7
  #   Ubuntu 14.04: due to necessary hacky work-arounds to this bug: https://bugs.launchpad.net/ubuntu/+source/realmd/+bug/1333694
  execute 'join_domain' do
    sensitive true
    command "echo -n '#{realm_databag_contents['password']}' | adcli join --host-fqdn #{computer_name} -U #{realm_databag_contents['username']} #{node['sssd']['directory_name']} --stdin-password"
    not_if "klist -k | grep -i '@#{node['sssd']['directory_name']}'"
  end
end

case node['platform']
when 'ubuntu'
  template '/usr/share/pam-configs/my_mkhomedir' do
    source 'my_mkhomedir.erb'
    owner 'root'
    group 'root'
    mode '0644'
    notifies :run, 'execute[pam-auth-update]'
  end

  # Enable automatic home directory creation
  execute 'pam-auth-update' do
    command 'pam-auth-update --package'
    action :nothing
  end
when 'centos'
  bash 'enable_sssd' do
    user 'root'
    code <<-EOF
    authconfig --enablemkhomedir --enablesssd --enablesssdauth --update
    echo 'sudoers:    files sss' >> /etc/nsswitch.conf
    EOF
    not_if "grep -i 'sudoers:    files sss' /etc/nsswitch.conf"
  end
end

template '/etc/sssd/sssd.conf' do
  source 'sssd.conf.erb'
  owner 'root'
  group 'root'
  mode '0600'
  notifies :restart, 'service[sssd]', :immediately if node['sssd']['join_domain'] == true
  variables({
    :domain => node['sssd']['directory_name'],
    :realm => node['sssd']['directory_name'].upcase,
    :enumerate => node['sssd']['enumerate']
  })
end

service 'sssd' do
  supports :status => true, :restart => true, :reload => true
  action node['sssd']['service_actions']
end
