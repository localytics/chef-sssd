require 'spec_helper'

describe package('sssd') do
  it { should be_installed }
end

describe service('sssd') do
  it { should be_enabled }
  it { should be_running }
end

describe file('/etc/sssd/sssd.conf') do
  it { should be_file }
  it { should be_mode 600 }
end

describe user($node['sssd']['realm']['user']) do
  it { should exist }
end

describe command("/usr/bin/sss_ssh_authorizedkeys #{$node['sssd']['realm']['user']}") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /^ssh-rsa / }
end

describe command("/usr/bin/sudo -U #{$node['sssd']['realm']['user']} -l") do
  its(:stdout) { should_not match /is not allowed to run sudo on/ }
end
