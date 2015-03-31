Introduction
============

We were recently faced with the challenge of implementing a centralized directory service for our AWS infrastructure. Having to sync multiple backends for our numerous applications that required authentication was getting cumbersome. Additionally, it was also necessary for us to support managing SSH keys and altering sudo permissions on running instances, as re-deploying infrastructure or performing a configuration management run (in our case, Chef) every time a key changed or a new hire joined had became too tedious. We researched numerous options, but ultimately decided on a combination of Amazon services and new features in Ubuntu 14.04 and CentOS 6.x to achieve our goals. This document will guide you through how and why we made the decisions we did, and how you can duplicate our setup in your own environment. We implemented our setup using Ubuntu 14.04 and CentOS 6.6; however, this cookbook likely supports other Linux distributions.

Amazon Simple AD
----------------

The first step in implementing a solution was to decide on a backend LDAP-compatible directory. Initially, we considered using OpenLDAP server, but that plan was met with many hesitations. Particularly, we were worried about the amount of work required to expand on the existing OpenLDAP Chef cookbook to meet our needs. Also, we generally prefer to utilize "as a service" tools as often as possible, and this was no exception: maintaining production OpenLDAP infrastructure, including replication, high-availability, and backups, was a responsibility our development team was hopeful to avoid. Eventually, we decided to move forward With Amazon's [Directory Service](http://aws.amazon.com/directoryservice/). Although geared as a replacement for Microsoft's Active Directory and therefore targeted for Windows instances, a Simple AD instance is still LDAP (actually, Samba) under the hood. Fortunately, it met all of our requirements for a directory service and was an obvious best choice, albeit with a few limitations which we'll get into in a bit.

SSSD
----

From past experience, we were well-aware of the directory integration features of pam and nss with pam_ldap and nss_ldap, respectively, along with nscld. However, these modules have historically been troublesome and often-times not well documented. Furthermore, caching support was non-existent and an outage of LDAP connectivity would leave servers inaccessible and/or unreliable. Enter SSSD, the centralized access point for all authentication and authorization requests for pam, nss, sudo, and more. Additionally, it supports numerous backends, such as LDAP, Active Directory, and FreeIPA, with enhanced caching support to reduce strain on directory servers and provide relief in a service outage. Also, a built-in sss_ssh_authorizedkeys utility allows for the searching of an LDAP backend to retrieve SSH keys. For our setup, SSSD was a no-brainer, especially because Ubuntu 14.04 LTS and CentOS 6.x ship with a recent version that included the enhanced features we need!

OPENSSH
-------

While SSSD provides a mechanism for fetching SSH keys from LDAP, OpenSSH still needs to be able to read and trust those keys as if they were in the usual location (.ssh/authorized_keys). A few years ago, a patch to OpenSSH was circulating that added an "AuthorizedKeysCommand" configuration parameter that specified a command string to execute that would return keys for a given user. CentOS 6.x received this patch. Fortunately, a similar patch finally made its way upstream, and as of Ubuntu 14.04 is available as part of the OpenSSH package. No more re-deploying configuration management or running complicated scripts just to replace SSH keys!

TYING IT ALL TOGETHER
=====================

The SSSD service allows us to centralize password authentication, public/private key authentication, host access, and sudo roles and access. Unfortunately, the Simple AD service (as of this time) doesn't support SSL connections, which is a requirement for utilizing the LDAP identity provider inside SSSD. We were fortunate enough to be able to work around this problem by utilizing a combination of the AD and LDAP provider backends. As luck would have it, the sss_ssh_authorizedkeys script previously mentioned ignores any backend configuration and will simply use any ldap_* configuration if present, without the requirement of SSL.

AMAZON SIMPLE AD SETUP
----------------------

To begin, spin up an Amazon Simple AD instance. You'll need to load some custom schema files. First, create sudo.ldif with the following contents, being sure to replace the Base DN references with the Base DN of your directory server (in our examples, we're using example.com):

  ```
  dn: CN=sudoUser,CN=Schema,CN=Configuration,DC=example,DC=com
  objectClass: top
  objectClass: attributeSchema
  attributeID: 1.3.6.1.4.1.15953.9.1.1
  schemaIDGUID:: JrGcaKpnoU+0s+HgeFjAbg==
  cn: sudoUser
  name: sudoUser
  lDAPDisplayName: sudoUser
  adminDisplayName: sudoUser
  adminDescription: User(s) who may run sudo
  attributeSyntax: 2.5.5.5
  isSingleValued: FALSE
  showInAdvancedViewOnly: TRUE
  oMSyntax: 22
  searchFlags: 1
  
  dn: CN=sudoHost,CN=Schema,CN=Configuration,DC=example,DC=com
  objectClass: top
  objectClass: attributeSchema
  attributeID: 1.3.6.1.4.1.15953.9.1.2
  schemaIDGUID:: d0TTjg+Y6U28g/Y+ns2k4w==
  cn: sudoHost
  name: sudoHost
  lDAPDisplayName: sudoHost
  adminDisplayName: sudoHost
  adminDescription: Host(s) who may run sudo
  attributeSyntax: 2.5.5.5
  isSingleValued: FALSE
  showInAdvancedViewOnly: TRUE
  oMSyntax: 22
  
  dn: CN=sudoCommand,CN=Schema,CN=Configuration,DC=example,DC=com
  objectClass: top
  objectClass: attributeSchema
  attributeID: 1.3.6.1.4.1.15953.9.1.3
  schemaIDGUID:: D6QR4P5UyUen3RGYJCHCPg==
  cn: sudoCommand
  name: sudoCommand
  lDAPDisplayName: sudoCommand
  adminDisplayName: sudoCommand
  adminDescription: Command(s) to be executed by sudo
  attributeSyntax: 2.5.5.5
  isSingleValued: FALSE
  showInAdvancedViewOnly: TRUE
  oMSyntax: 22
  
  dn: CN=sudoRunAs,CN=Schema,CN=Configuration,DC=example,DC=com
  objectClass: top
  objectClass: attributeSchema
  attributeID: 1.3.6.1.4.1.15953.9.1.4
  schemaIDGUID:: CP98mCQTyUKKxGrQeM80hQ==
  cn: sudoRunAs
  name: sudoRunAs
  lDAPDisplayName: sudoRunAs
  adminDisplayName: sudoRunAs
  adminDescription: User(s) impersonated by sudo (deprecated)
  attributeSyntax: 2.5.5.5
  isSingleValued: FALSE
  showInAdvancedViewOnly: TRUE
  oMSyntax: 22
  
  dn: CN=sudoOption,CN=Schema,CN=Configuration,DC=example,DC=com
  objectClass: top
  objectClass: attributeSchema
  attributeID: 1.3.6.1.4.1.15953.9.1.5
  schemaIDGUID:: ojaPzBBlAEmsvrHxQctLnA==
  cn: sudoOption
  name: sudoOption
  lDAPDisplayName: sudoOption
  adminDisplayName: sudoOption
  adminDescription: Option(s) followed by sudo
  attributeSyntax: 2.5.5.5
  isSingleValued: FALSE
  showInAdvancedViewOnly: TRUE
  oMSyntax: 22
  
  dn: CN=sudoRunAsUser,CN=Schema,CN=Configuration,DC=example,DC=com
  objectClass: top
  objectClass: attributeSchema
  attributeID: 1.3.6.1.4.1.15953.9.1.6
  schemaIDGUID:: 9C52yPYd3RG3jMR2VtiVkw==
  cn: sudoRunAsUser
  name: sudoRunAsUser
  lDAPDisplayName: sudoRunAsUser
  adminDisplayName: sudoRunAsUser
  adminDescription: User(s) impersonated by sudo
  attributeSyntax: 2.5.5.5
  isSingleValued: FALSE
  showInAdvancedViewOnly: TRUE
  oMSyntax: 22
  
  dn: CN=sudoRunAsGroup,CN=Schema,CN=Configuration,DC=example,DC=com
  objectClass: top
  objectClass: attributeSchema
  attributeID: 1.3.6.1.4.1.15953.9.1.7
  schemaIDGUID:: xJhSt/Yd3RGJPTB1VtiVkw==
  cn: sudoRunAsGroup
  name: sudoRunAsGroup
  lDAPDisplayName: sudoRunAsGroup
  adminDisplayName: sudoRunAsGroup
  adminDescription: Groups(s) impersonated by sudo
  attributeSyntax: 2.5.5.5
  isSingleValued: FALSE
  showInAdvancedViewOnly: TRUE
  oMSyntax: 22
  
  dn: CN=sudoNotBefore,CN=Schema,CN=Configuration,DC=example,DC=com
  objectClass: top
  objectClass: attributeSchema
  attributeID: 1.3.6.1.4.1.15953.9.1.8
  schemaIDGUID:: dm1HnRfY4RGf4gopYYhwmw==
  cn: sudoNotBefore
  name: sudoNotBefore
  lDAPDisplayName:  sudoNotBefore
  adminDisplayName: sudoNotBefore
  adminDescription: Start of time interval for which the entry is valid
  attributeSyntax: 2.5.5.11
  isSingleValued: TRUE
  showInAdvancedViewOnly: TRUE
  oMSyntax: 24
  
  dn: CN=sudoNotAfter,CN=Schema,CN=Configuration,DC=example,DC=com
  objectClass: top
  objectClass: attributeSchema
  attributeID: 1.3.6.1.4.1.15953.9.1.9
  schemaIDGUID:: OAr/pBfY4RG9dBIpYYhwmw==
  cn: sudoNotAfter
  name: sudoNotAfter
  lDAPDisplayName:  sudoNotAfter
  adminDisplayName: sudoNotAfter
  adminDescription: End of time interval for which the entry is valid
  attributeSyntax: 2.5.5.11
  isSingleValued: TRUE
  showInAdvancedViewOnly: TRUE
  oMSyntax: 24
  
  dn: CN=sudoOrder,CN=Schema,CN=Configuration,DC=example,DC=com
  objectClass: top
  objectClass: attributeSchema
  attributeID: 1.3.6.1.4.1.15953.9.1.10
  schemaIDGUID:: 0J8yrRfY4RGIYBUpYYhwmw==
  cn: sudoOrder
  name: sudoOrder
  lDAPDisplayName:  sudoOrder
  adminDisplayName: sudoOrder
  adminDescription: an integer to order the sudoRole entries
  attributeSyntax: 2.5.5.9
  isSingleValued: TRUE
  showInAdvancedViewOnly: TRUE
  oMSyntax: 2
  
  dn: CN=sudoRole,CN=Schema,CN=Configuration,DC=example,DC=com
  objectClass: top
  objectClass: classSchema
  governsID: 1.3.6.1.4.1.15953.9.2.1
  schemaIDGUID:: SQn432lnZ0+ukbdh3+gN3w==
  cn: sudoRole
  name: sudoRole
  lDAPDisplayName: sudoRole
  possSuperiors: container
  possSuperiors: top
  subClassOf: top
  mayContain: sudoCommand
  mayContain: sudoHost
  mayContain: sudoOption
  mayContain: sudoRunAs
  mayContain: sudoRunAsUser
  mayContain: sudoRunAsGroup
  mayContain: sudoUser
  mayContain: sudoNotBefore
  mayContain: sudoNotAfter
  mayContain: sudoOrder
  showInAdvancedViewOnly: FALSE
  adminDisplayName: sudoRole
  adminDescription: Sudoer Entries
  objectClassCategory: 1
  systemOnly: FALSE
  defaultObjectCategory: CN=sudoRole,CN=Schema,CN=Configuration,DC=example,DC=com
  ```

Then, create ssh.ldif with the following contents, being sure to replace the Base DN references with the Base DN of your directory server (ie: dc=example,dc=com):

  ```
  dn: CN=sshPublicKey,CN=Schema,CN=Configuration,DC=example,DC=com
  changetype: add
  objectClass: top
  objectClass: attributeSchema
  attributeID: 1.3.6.1.4.1.1466.115.121.1.40
  cn: sshPublicKey
  name: sshPublicKey
  lDAPDisplayName: sshPublicKey
  description: Users public SSH key
  attributeSyntax: 2.5.5.5
  oMSyntax: 22
  isSingleValued: FALSE

  dn: CN=ldapPublicKey,CN=Schema,CN=Configuration,DC=example,DC=com
  changetype: add
  objectClass: top
  objectClass: classSchema
  governsID: 1.3.6.1.4.1.1466.115.121.1.40
  cn: ldapPublicKey
  name: ldapPublicKey
  lDAPDisplayName: ldapPublicKey
  description: Used to store SSH keys in LDAP
  subClassOf: top
  objectClassCategory: 3
  mayContain: sshPublicKey
  mayContain: uid
  ```

Next, create sudoers.ldif with SIMILAR contents to the following, being sure to replace the Base DN references with the Base DN of your directory server (ie: dc=example,dc=com). This example LDIF creates a root sudo role and gives *all users* access to that role:

  ```
    ```

To load these LDIFS, execute the following, being sure to replace place-holders with proper values. If you get an error that --user is an invalid option, you'll want to make sure you have the samba package installed alongside ldb-tools:

  ```bash
  ldbadd -H "ldap://example.com" sudo.ldif --user "<Admin Account Username>" --password "<Admin Account Password>"
  ldbadd -H "ldap://example.com" ssh.ldif --user "<Admin Account Username>" --password "<Admin Account Password>"
  ldbadd -H "ldap://example.com" sudoers.ldif --user "<Admin Account Username>" --password "<Admin Account Password>"
  ```

Now, create at least two users: one that will be used to test that the setup is functioning correctly, and the other that will be used by SSSD to access sudoers data inside LDAP. For our example below (users.ldif), we have "tuser" and "suser":

  ```
  dn: CN=Test User,CN=Users,DC=example,DC=com
  cn: Test User
  sn: User
  givenName: Test
  displayName: Test User
  name: Test User
  sAMAccountName: tuser
  userPrincipalName: tuser@example.com
  instanceType: 4
  badPwdCount: 0
  codePage: 0
  countryCode: 0
  badPasswordTime: 0
  lastLogoff: 0
  lastLogon: 0
  accountExpires: 9223372036854775807
  logonCount: 0
  pwdLastSet: 130598522940000000
  lockoutTime: 0
  userAccountControl: 66048
  msDS-SupportedEncryptionTypes: 0
  objectClass: top
  objectClass: person
  objectClass: organizationalPerson
  objectClass: user
  
  dn: CN=SSSD User,CN=Users,DC=example,DC=com
  cn: SSSD User
  sn: User
  givenName: SSSD
  displayName: SSSD User
  name: SSSD User
  sAMAccountName: suser
  userPrincipalName: suser@example.com
  instanceType: 4
  badPwdCount: 0
  codePage: 0
  countryCode: 0
  badPasswordTime: 0
  lastLogoff: 0
  lastLogon: 0
  accountExpires: 9223372036854775807
  logonCount: 0
  pwdLastSet: 130598522940000000
  lockoutTime: 0
  userAccountControl: 66048
  msDS-SupportedEncryptionTypes: 0
  objectClass: top
  objectClass: person
  objectClass: organizationalPerson
  objectClass: user
  ```

And import:

  ```bash
  ldbadd -H "ldap://example.com" users.ldif --user "<Admin Account Username>" --password "<Admin Account Password>"
  ```

Utilizing a host that has samba-tool installed, set passwords for the above new accounts, being sure to replace place-holders with proper values:

  ```bash
  samba-tool user setpassword --newpassword "<password>" -H "ldap://example.com" --user "<Admin Account Username>" --password "<Admin Account Password>" suser
  samba-tool user setpassword --newpassword "<password>" -H "ldap://example.com" --user "<Admin Account Username>" --password "<Admin Account Password>" tuser
  ```
  
You must also grant authentication users read access to the ou=Sudoers container that was created via the above LDIF. Again, using samba-tool:

  ```bash
  samba-tool dsacl set -H "ldap://example.com" --user "<Admin Account Username>" --password "<Admin Account Password>" --objectdn="CN=Sudoers,CN=Users,DC=example,DC=com" --sddl="(A;CI;GR;;;AU)"
  ```
  
Now add an SSH key to the *test user* you've created. Be sure to replace the Base DN references with the Base DN of your directory server (again, as an example: dc=example,dc=com) and populating a valid public SSH key:

  ```
  dn: CN=Test User,CN=Users,DC=example,DC=com
  changeType: modify
  add: objectClass
  objectClass: ldapPublicKey

  dn: cn=Test User,CN=Users,DC=example,DC=com
  changeType: modify
  add: sshPublicKey
  sshPublicKey: ssh-rsa .... tuser@Tests-Macbook-Air.local
  ```  

Apply the LDIF to your directory server:

  ```bash
  ldbmodify -H "ldap://example.com" add-key.ldif --user "<Admin Account Username>" --password "<Admin Account Password>"
  ```

Your Amazon Simple AD instance should now be properly configured. Next, we'll configure SSSD & OpenSSH on a test instance and tie it into the directory service.

SSSD & OPENSSH SETUP
--------------------

First, spin up a vanilla Ubuntu 14.04 LTS instance, switch to a root shell, and edit /etc/resolv.conf to contain something simliar to the following, being sure to replace the search domain with your AD domain and the nameserver IP addresses with the IPs of your Simple AD servers:

  ```
  search example.com
  nameserver 198.51.100.10
  nameserver 203.0.113.20
  ```

To test connectivity between your instance and Simple AD, execute:

  ```bash
  realm list
  ```

You should see information about your Simple AD domain.  Next, execute the following commands, being sure to replace the username and password references with valid administrator credentials for your directory server and the domain references with your valid AD domain:

  ```bash
  apt-get -y update
  apt-get -y install sssd sssd-ad sssd-ad-common sssd-tools realmd samba-common samba-libs samba-common-bin
  realm join -U <Admin Account Username> example.com
  ```

Your server should successfully be joined to the domain. Unfortunately, realm doesn't give us a completely usable SSSD configuration file, so it's necessary to overwrite /etc/sssd/sssd.conf with the following, being sure to replace any example.com references with your actual configuration and fill in appropriate credentials:

  ```
  [sssd]
  config_file_version = 2
  services = nss, pam, ssh, sudo
  domains = example.com

  [nss]
  filter_users = root,named,avahi,haldaemon,dbus,radiusd,news,nscd

  [pam]

  [ssh]

  [sudo]

  [domain/example.com]
  id_provider = ad
  access_provider = ad
  auth_provider = ad
  chpass_provider = ad
  sudo_provider = ldap

  ad_domain = example.com
  krb5_realm = EXAMPLE.COM
  realmd_tags = manages-system joined-with-samba 
  cache_credentials = True
  krb5_store_password_if_offline = True
  default_shell = /bin/bash
  ldap_id_mapping = True
  fallback_homedir = /home/%u

  ldap_tls_reqcert = never
  ldap_uri = ldap://example.com
  ldap_search_base = dc=example,dc=com
  ldap_user_search_base = cn=Users,dc=example,dc=com
  ldap_user_object_class = user
  ldap_user_name = sAMAccountName
  ldap_user_ssh_public_key = sshPublicKey
  ldap_group_search_base = cn=Users,dc=example,dc=com
  ldap_sudo_search_base = cn=Sudoers,cn=Users,dc=example,dc=com
  ldap_default_bind_dn = suser@example.com
  ldap_default_authtok = ExamplePassword
  ```

Finally, add the following lines to /etc/ssh/sshd_config, which will tell OpenSSH to look for SSH keys via SSSD:

  ```
  AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
  AuthorizedKeysCommand root
  ```

Now restart SSSD and OpenSSH, and you should be all set:

  ```bash
  service sssd restart
  service ssh restart
  ```

TESTING YOUR SETUP
------------------

To test your setup, verify that SSSD can talk to Simple AD and fetch information about your test user (user and group information should be returned):

  ```bash
  id tuser
  ```

Next, verify that SSH keys can be accessed (an SSH key should be returned):

  ```bash
  /usr/bin/sss_ssh_authorizedkeys tuser
  ```

Finally, verify that your test user has root sudo privileges (root sudo privilege information should be returned):

  ```bash
  /usr/bin/sudo -U tuser -l
  ```

CHEF COOKBOOK
=============

Testing the configuration of Simple AD, SSSD, and OpenSSH is simple with our SSSD and OpenSSH chef cookbooks, accessible at:

  - http://www.github.com/localytics/chef-sssd.git
  - http://www.github.com/localytics/chef-ly-openssh.git

In order to test that your SSSD & Simple AD setup is working properly, you'll need to run the following on a host that has access to a configured Simple AD instance. At Localytics, we use VPN to gain access from our local machines, but YMMV. While you probably want to setup the following in an organization-specific wrapper cookbook, we've tried to make it as easy as possible to clone the sssd cookbook and simply "get it working".

To get started, make sure you have the chef-dk installed (https://downloads.chef.io/chef-dk/) and a sane ruby setup, then simply:

  ```bash
  git clone git@github.com:localytics/chef-sssd
  cd chef-sssd
  gem install bundler
  bundle
  cp .kitchen.local.yml.EXAMPLE .kitchen.local.yml
  ```

Then edit your .kitchen.local.yml with the IP addresses of your primary and secondary AD servers, AD domain, and a user that has at least one public key and one sudo role configured). The latter is used by integration tests to verify that all services are functioning correctly. FYI, our example user, 'Guest', likely does NOT have the configuration necessary to pass the tests. You'll want to make this 'tuser' if you used our examples above.

Next, create an encrypted data bag key used for locally created data bags:

  ```bash
  mkdir -p test/support/data_bags
  openssl rand -base64 512 | tr -d '\r\n' > test/support/encrypted_data_bag_secret
  ```

Then, configure an encrypted data bag with a valid administrative username and password, used for joining the domain with 'realm':

  ```bash
  knife solo data bag create sssd_credentials realm -c .chef/solo.rb
  ```

The format of the data bag is:

  ```json
  {
    "id": "realm",
    "user": "administrator",
    "password": "password"
  }
  ```

Next, create a data bag with a username and password that has access to read ou=Sudoers inside Simple AD (if you used our example ACL above, this is any authenticated user):

  ```bash
  knife solo data bag create sssd_credentials ldap -c .chef/solo.rb
  ```

The format of the data bag is:

  ```json
  {
    "id": "ldap",
    "user": "suser",
    "password": "password"
  }
  ```

Once you're all set, simply:

  ```bash
  bundle exec kitchen test
  ```

... and watch! If all tests pass, you've successfully configured your Simple AD server.

Comments and feedback on our setup are welcome!
