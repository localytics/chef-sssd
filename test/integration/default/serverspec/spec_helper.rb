require 'serverspec'
require 'pathname'
require 'net/http'
require 'net/smtp'
require 'json'

set :backend, :exec

$node = ::JSON.parse(File.read('/tmp/serverspec/node.json'))
