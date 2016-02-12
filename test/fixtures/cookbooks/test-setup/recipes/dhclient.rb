if node['platform'] == 'centos'

  # On centos, disable dhclient from updating /etc/resolv.conf:
  #   https://www.centos.org/forums/viewtopic.php?t=24741

  directory '/etc/dhcp' do
    mode "0755"
  end

  cookbook_file '/etc/dhcp/dhclient-enter-hooks' do
    mode "0755"
  end

end
