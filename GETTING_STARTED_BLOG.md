<article>
# Implementing a Centralized Directory Service for AWS Infrastructure with Amazon Simple AD and SSSD

## Introduction
Need a centralized directory service for your AWS infrastructure? Weary of all the muss and fuss required to manage SSH keys on running instances? Read on for step-by-step advice on a straightforward, open solution based on Amazon services plus new features in Ubuntu 14.04 and CentOS 6.x. (It will probably work with other Linux distributions as well).

First, we needed an LDAP-compatible backend directory. We balked at using OpenLDAP because of the effort required to customize the OpenLDAP Chef cookbook for our needs. Also, we prefer to utilize "as-a-service" tools whenever possible to simplify administration.

Enter Amazon's Simple AD. Although geared to replace Microsoft Active Directory and therefore targeted for Windows instances, a Simple AD instance is still LDAP (actually, Samba) under the hood—making it an obvious best choice, albeit with a few limitations which I will explain shortly.

From past experience, we were aware of the directory integration features of PAM and NSS with pam\_ldap and nss\_ldap, respectively, along with nslcd. However, these modules have historically been troublesome and not well documented. Furthermore, their caching support is nonexistent, so an LDAP connectivity outage would leave servers inaccessible or unreliable.

Enter SSSD, the centralized access point for all authentication and authorization requests for pam, nss, sudo, and more. SSSD also supports numerous backends, such as LDAP, Active Directory, and FreeIPA, with enhanced caching support to reduce strain on directory servers and provide relief in a service outage. Also, a built-in sss\_ssh\_authorizedkeys utility enables searching a supported backend to retrieve SSH keys. To seal the deal, Ubuntu 14.04 LTS and CentOS 6.x ship with a recent SSSD version that includes these key features.

While SSSD provides a mechanism for fetching SSH keys from LDAP, OpenSSH still needs to read and trust those keys as if they were in the usual location (.ssh/authorized_keys). CentOS 6.x and Ubuntu 14.04 now both have a patch to OpenSSH that adds an "AuthorizedKeysCommand" configuration parameter, which specifies a command string to return keys for a given user. No more redeploying configuration management or running complicated scripts just to replace SSH keys!

The SSSD service allows us to centralize password authentication, public/private key authentication, host access, and sudo roles and access. Unfortunately, the Simple AD service (as of this time) doesn't support SSL connections, which is a requirement for utilizing the LDAP identity provider inside SSSD. Fortunately, the AD backend, which works well with Simple AD, did not have this limitation.

## Amazon Simple AD Setup
To tie everything together, you start by spinning up a Simple AD instance. You'll need to load some custom schema files. First, create `sudo.ldif` with [these contents](#sudo.ldif)<a name='sudo.ldif-article'></a>, then create `ssh.ldif` with [these contents](#ssh.ldif)<a name='ssh.ldif-article'></a>. Finally create `sudoers.ldif` with contents [similar to this](#sudoers.ldif)<a name='sudoers.ldif-article'></a>, which will create a root sudo role and gives *all users* access to it. Make sure to replace the Base DN references in each entry with the Base DN of your directory server (i.e., dc=example, dc=com).

To load these LDIFS, execute [these commands](#load-ldifs)<a name='load-ldifs-article'></a> in your terminal, being sure to replace placeholders with proper values. If you get an error that `--user` is an invalid option, make sure you have the samba package installed alongside `ldb-tools`.

Now create a user so you can test your setup. In [this example](#users.ldif)<a name='users.ldif-article'></a>, the user is "tuser". Once the user is created, it must be imported by issuing the associated `ldbadd` command. If you have a host  with `samba-tool` installed, you have the option to set a password for the new account.

You must also use `samba-tool` to grant authenticated users read access to the `CN=Sudoers` container that was created via previous LDIFs. [These commands](#auth-read-access)<a name='auth-read-access-article'></a> must be run against each AD Server (as this will not replicate).

Now [add an SSH key](#ssh-key-ldap)<a name='ssh-key-ldap-article'></a> to the test user you've created and apply the LDIF.

Your Simple AD instance should now be properly configured. The next step is to configure SSSD and OpenSSH using a test instance and tie it into the directory service.

## SSSD & OpenSSH Setup
First, spin up a vanilla Ubuntu 14.04 LTS instance, switch to a root shell, and edit `/etc/resolv.conf` to [include your search domain and nameservers](#resolvconf)<a name='resolvconf-article'></a>, making sure to use the correct IP addresses and domain name. Once that is in place, execute `realm list` in the CLI to test connectivity between your instance and Simple AD. You should see information about your Simple AD domain.

Assuming that everything is working so far, the next step is to [install](#join-domain) the `sssd` and `samba` packages and [join](#join-domain) the Simple AD domain<a name='join-domain-article'></a>. There is a [known bug](https://bugs.launchpad.net/ubuntu/+source/realmd/+bug/1333694) that can cause a package error during realm join which we have worked around by termporarily using `adcli` in our Chef cookbook. Your server should now be successfully joined to the domain. Unfortunately, realm doesn't give you a completely usable SSSD configuration file, so it's necessary to overwrite `/etc/sssd/sssd.conf` with [this](#sssdconf)<a name='sssdconf-article'></a>.

## Testing Your Setup
To test your setup, run `id tuser` to verify that SSSD can talk to Simple AD and retrieve user and group information about your test user. Next, verify that it can access and return SSH keys with `/usr/bin/sss_ssh_authorizedkeys tuser`. Finally, verify that your test user has root sudo privileges with `/usr/bin/sudo -U tuser -l`.

### Chef Cookbook
Testing the configuration of Simple AD, SSSD, and OpenSSH is simple with our Chef cookbooks which are available on GitHub:

<http://www.github.com/localytics/chef-sssd.git><br/>
<http://www.github.com/localytics/chef-ly-openssh.git><br/>

While you probably want to use an organization-specific wrapper cookbook, we have tried to make it as easy as possible to clone the SSSD cookbook and simply "get it working". As noted above, our Chef cookbook temporarily uses `adcli` instead of `realm` to join the domain due to [this bug](https://bugs.launchpad.net/ubuntu/+source/realmd/+bug/1333694). Future versions will revert back to using `realm`. To get started, make sure you have the `chef-dk` installed and a sane Ruby setup, then simply clone and set up the sssd cookbook and [run the default test suite](#clone-sssd-cookbook)<a name='clone-sssd-cookbook-article'></a>. This will ensure that all of the packages and configurations necessary for joining the domain are in place.

In order to verify that it is possible to join and interact with your newly configured domain, copy `.kitchen.local.yml.EXAMPLE` to `.kitchen.local.yml` and update it to match your environment details, such as EC2 instance information, IP addresses of your primary and secondary AD servers, AD domain, and a user that has at least one public key and one sudo role configured. The user that you specify is used by integration tests to verify that all services are functioning correctly. Our default test user, “Guest,” likely does not have the configuration necessary to pass the integration tests so you'll want to make this “tuser” if you used our examples above.

Next, [create](#data-bag)<a name='data-bag-article'></a> an encrypted data bag key used for locally created data bags and configure an encrypted data bag with a valid administrative username and password, used for joining the domain with `realm`. Once you're all set, simply `chef exec kitchen test with-registration` and voilà! If all tests pass, you've successfully configured your Simple AD server.

Comments and feedback on our setup are welcome!


<footer>
### Amazon Simple AD Snippets
<a name='sudo.ldif'></a>
####sudo.ldif
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
objectClass: attributeSchemassl
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
[Return to article](#sudo.ldif-article)

<a name='ssh.ldif'></a>
####ssh.ldif
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
[Return to article](#ssh.ldif-article)

<a name='sudoers.ldif'></a>
####sudoers.ldif
```
dn: CN=Sudoers,DC=example,DC=com
objectClass: top
objectClass: container
cn: Sudoers
name: Sudoers
description: Default container for Sudoers configuration
distinguishedName: CN=Sudoers,DC=example,DC=com

# sudo defaults
dn: cn=defaults,CN=Sudoers,DC=example,DC=com
objectClass: top
objectClass: sudoRole
cn: defaults
description: Default sudoOptions go here
sudoOption: env_keep+=SSH_AUTH_SOCK

dn: CN=root,CN=Sudoers,DC=example,DC=com
objectClass: top
objectClass: sudoRole
cn: root
sudoHost: ALL
sudoCommand: ALL
sudoUser: ALL
```
[Return to article](#sudoers.ldif-article)

<a name='load-ldifs'></a>
####Load all LDIFs
```
$ ldbadd -H "ldap://example.com" sudo.ldif --user "<Admin Account Username>" --password "<Admin Account Password>"
$ ldbadd -H "ldap://example.com" ssh.ldif --user "<Admin Account Username>" --password "<Admin Account Password>"
$ ldbadd -H "ldap://example.com" sudoers.ldif --user "<Admin Account Username>" --password "<Admin Account Password>"
```
[Return to article](#load-ldifs-article)

<a name='users.ldif'></a>
####users.ldif
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
```
####Load Test User
```
$ ldbadd -H "ldap://example.com" users.ldif --user "<Admin Account Username>" --password "<Admin Account Password>"
```
####Set Password For Test User
```
$ samba-tool user setpassword --newpassword "<password>" -H "ldap://example.com" --user "<Admin Account Username>" --password "<Admin Account Password>" tuser
```
[Return to article](#users.ldif-article)

<a name='auth-read-access'></a>
####Grant Authenticated Read Access
```
$ samba-tool dsacl set -H "ldap://198.51.100.10" --user "<Admin Account Username>" --password "<Admin Account Password>" --objectdn="CN=Sudoers,DC=example,DC=com" --sddl="(A;CI;GR;;;AU)"
$ samba-tool dsacl set -H "ldap://203.0.113.20" --user "<Admin Account Username>" --password "<Admin Account Password>" --objectdn="CN=Sudoers,DC=example,DC=com" --sddl="(A;CI;GR;;;AU)"
```
[Return to article](#auth-read-access-article)

<a name='ssh-key-ldap'></a>
####User SSH Key LDAP Entry
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
####Apply SSH Key Update
```
$ ldbmodify -H "ldap://example.com" add-key.ldif --user "<Admin Account Username>" --password "<Admin Account Password>"
```
[Return to article](#ssh-key-ldap-article)

### SSSD & OpenSSH Snippets
<a name='resolvconf'></a>
#### resolv.conf
```
search example.com
nameserver 198.51.100.10
nameserver 203.0.113.20
```
[Return to article](#resolvconf-article)

<a name='join-domain'></a>
#### Install Packages and Join Domain
```
$ apt-get -y update
$ apt-get -y install sssd sssd-ad sssd-ad-common sssd-tools realmd samba-common samba-libs samba-common-bin
$ realm join -U <Admin Account Username> example.com
```
[Return to article](#join-domain-article)

<a name='sssdconf'></a>
#### /etc/sssd/sssd.conf
```
[sssd]
config_file_version = 2
services = nss, pam, ssh, sudo
domains = example.com

[nss]
filter_users = root,named,avahi,haldaemon,dbus,radiusd,news,nscd,centos,ubuntu

[pam]

[ssh]

[sudo]

[domain/example.com]
id_provider = ad
access_provider = ad

ad_domain = example.com
krb5_realm = EXAMPLE.COM
realmd_tags = manages-system joined-with-samba
cache_credentials = True
krb5_store_password_if_offline = True
default_shell = /bin/bash
ldap_id_mapping = True
fallback_homedir = /home/%u

ldap_user_ssh_public_key = sshPublicKey
```
[Return to article](#sssdconf-article)

<a name='clone-sssd-cookbook'></a>
#### Clone And Set Up SSSD Cookbook
```
$ git clone git@github.com:localytics/chef-sssd
$ cd chef-sssd
$ chef exec kitchen test default
```
[Return to article](#clone-sssd-cookbook-article)

<a name='data-bag'></a>
#### Create Encrypted Data Bags
```
$ openssl rand -base64 512 | tr -d '\r\n' > test/integration/with-registration/encrypted_data_bag_secret_key
$ knife solo data bag create sssd_credentials realm -c .chef/solo.rb
```

##### Data Bag Format
```
{
  "id": "realm",
  "username": "administrator",
  "password": "password"
}
```
[Return to article](#data-bag-article)
</footer>
</article>
