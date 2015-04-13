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

# We sleep until the test user is "resolvable", up to five minutes,
# due to not having an easy way of actually knowing if SSSD is online yet:
#   https://fedorahosted.org/sssd/ticket/385
describe command("fail_count=0; while ! id #{$node['sssd']['test_user']}; do sleep 5; fail_count=$(expr $fail_count + 1); if [ $fail_count -gt 60 ]; then exit 1; fi; done") do
  its(:exit_status) { should eq 0 }
end

# We sleep until the test user has accessible sudo rules, up to five minutes,
# due to not having an easy way of actually knowing if SSSD is online yet:
#   https://fedorahosted.org/sssd/ticket/385
describe command("fail_count=0; while ! sudo -U #{$node['sssd']['test_user']} -l | grep 'may run the following commands on'; do sleep 5; fail_count=$(expr $fail_count + 1); if [ $fail_count -gt 60 ]; then exit 1; fi; done") do
  its(:exit_status) { should eq 0 }
end

describe user($node['sssd']['test_user']) do
  it { should exist }
end

describe command("/usr/bin/sss_ssh_authorizedkeys #{$node['sssd']['test_user']}") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /^ssh-rsa / }
end

# Used just to create the directory if it doesn't already exist
describe command("/bin/su #{$node['sssd']['test_user']} -c /bin/true") do
  its(:exit_status) { should eq 0 }
end

describe file("/home/#{$node['sssd']['test_user']}") do
  it { should be_directory }
end

describe command("/usr/bin/sudo -U #{$node['sssd']['test_user']} -l") do
  its(:stdout) { should match /User #{$node['sssd']['test_user']} may run the following commands on/ }
end
