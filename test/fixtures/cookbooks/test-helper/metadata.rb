name             'test-helper'
description      'Dumps chef node data to json file'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.0.1'

recipe 'default', 'Dumps chef node data to json file'

%w{ ubuntu centos }.each do |os|
  supports os
end
