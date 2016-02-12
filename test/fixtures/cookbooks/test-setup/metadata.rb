name             'test-setup'
description      'Various sssd related test recipes'
version          '0.0.1'

%w{ ubuntu centos }.each do |os|
  supports os
end
