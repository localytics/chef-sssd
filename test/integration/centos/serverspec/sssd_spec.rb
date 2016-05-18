require 'spec_helper'

describe package('adcli') do
  it { should be_installed }
end

describe package('sssd') do
  it { should be_installed }
end

describe service('sssd') do
  it { should be_enabled }
  it { should_not be_running }
end

describe file('/etc/sssd/sssd.conf') do
  it { should be_file }
  it { should be_mode 600 }
end
