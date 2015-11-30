# sssd-cookbook

Launch, configure, and manage the SSSD service for communication with an AD backend such as Amazon Directory Service (Simple AD)

## Supported Platforms

- Ubuntu 14.04 LTS
- CentOS 6.6

## Attributes

<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['sssd']['join_domain']</tt></td>
    <td>Boolean</td>
    <td>whether or not to join the domain (mostly useless to change unless testing)</td>
    <td><tt>true</tt></td>
  </tr>
  <tr>
    <td><tt>['sssd']['enumerate']</tt></td>
    <td>Boolean</td>
    <td>whether or not to enable enumeration (increased load on Simple AD servers, but some setups may need it)</td>
    <td><tt>true</tt></td>
  </tr>
  <tr>
    <td><tt>['sssd']['packages']</tt></td>
    <td>Array</td>
    <td>list of packages to install prior to adcli join</td>
    <td><tt>varies by OS</tt></td>
  </tr>
  <tr>
    <td><tt>['sssd']['computer_name']</tt></td>
    <td>String</td>
    <td>an optional alternate computer name to use when joining the domain (IE: ec2 instance ID)</td>
    <td><tt>nil</tt></td>
  </tr>
  <tr>
    <td><tt>['sssd']['directory_name']</tt></td>
    <td>String</td>
    <td>the directory name, as specified in "Directory Details" in the AWS console</td>
    <td><tt>nil</tt></td>
  </tr>
  <tr>
    <td><tt>['sssd']['realm']['databag']</tt></td>
    <td>String</td>
    <td>databag that contains the username and password used in "adcli join" or "realm join"</td>
    <td><tt>nil</tt></td>
  </tr>
  <tr>
    <td><tt>['sssd']['realm']['databag_item']</tt></td>
    <td>String</td>
    <td>databag item that contains the username and password used in "adcli join" or "realm join"</td>
    <td><tt>nil</tt></td>
  </tr>
</table>

## Usage

### sssd::default

Include `sssd` in your node's `run_list`:

```json
{
  "run_list": [
    "recipe[sssd::default]"
  ]
}
```

## Testing

See .kitchen.yml and .kitchen.local.yml.EXAMPLE.

To create a local databag for use with test kitchen's with-registration suite, do:

  ```bash
  $ openssl rand -base64 512 | tr -d '\r\n' > test/integration/with-registration/encrypted_data_bag_secret_key
  $ knife solo data bag create sssd_credentials realm -c .chef/solo.rb
  ```

## License and Authors

Author:: Localytics (oss@localytics.com)

```text
Copyright:: 2015, Localytics

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
