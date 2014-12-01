# sssd-cookbook

Launch, configure, and manage the SSSD service for communication with Amazon Directory Service (Simple DS)

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
    <td>Array</td>
    <td>active directory search domain (for use with resolver cookbook)</td>
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
