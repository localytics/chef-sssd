# sssd-cookbook

Launch, configure, and manage the SSSD service for communication with an AD backend such as Amazon Directory Service (Simple DS)

## Supported Platforms

- Ubuntu 14.04 LTS

## Attributes

<table>
  <tr>
    <th>Key</th>
    <th>Type</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>['resolver']['nameservers']</tt></td>
    <td>Array</td>
    <td>one or more active directory servers (for use with resolver cookbook)</td>
    <td><tt>nil</tt></td>
  </tr>
  <tr>
    <td><tt>['resolver']['search']</tt></td>
    <td>String</td>
    <td>active directory search domain (for use with resolver cookbook)</td>
    <td><tt>nil</tt></td>
  </tr>
  <tr>
    <td><tt>['sssd']['realm']['user']</tt></td>
    <td>String</td>
    <td>username to use to join the domain via realm</td>
    <td><tt>nil</tt></td>
  </tr>
  <tr>
    <td><tt>['sssd']['realm']['password']</tt></td>
    <td>String</td>
    <td>password to use to join the domain via realm</td>
    <td><tt>nil</tt></td>
  </tr>
  <tr>
    <td><tt>['sssd']['ldap']['user']</tt></td>
    <td>String</td>
    <td>optional username to use to access data via the ldap sssd provider</td>
    <td><tt>nil</tt></td>
  </tr>
  <tr>
    <td><tt>['sssd']['ldap']['password']</tt></td>
    <td>String</td>
    <td>optional password to use to access data via the ldap sssd provider</td>
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

## License and Authors

Author:: Char Software, Inc. (dev@localytics.com)

```text
Copyright:: 2014, Char Software, Inc.

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
