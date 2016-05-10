# -*- mode: ruby -*-
# vi: set ft=ruby :

source "https://supermarket.chef.io"

metadata

group :integration do
  cookbook 'apt'
  cookbook 'yum'
  cookbook 'test-helper', '>= 1.1.0'
  cookbook 'test-setup', path: 'test/fixtures/cookbooks/test-setup'
end
