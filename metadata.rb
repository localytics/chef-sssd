name             'sssd'
maintainer       'Localytics'
maintainer_email 'oss@localytics.com'
license          'Apache 2.0'
description      'Installs/Configures sssd for use with an AD backend such as Amazon DS'
long_description 'Installs/Configures sssd for use with an AD backend such as Amazon DS'
version          IO.read(File.join(File.dirname(__FILE__), 'VERSION')) rescue '0.0.1'

supports 'ubuntu', '>= 14.04'
supports 'centos', '>= 6.6'

depends 'apt', '~> 2.7.0'
depends 'yum', '~> 3.5.0'
depends 'yum-epel', '~> 0.6.0'
