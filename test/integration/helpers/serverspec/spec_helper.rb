require 'serverspec'
require 'json'

set :backend, :exec

$node = ::JSON.parse(File.read('/tmp/test-helper/node.json'))
