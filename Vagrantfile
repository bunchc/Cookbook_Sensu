# -*- mode: ruby -*-
# vi: set ft=ruby :

nodes = {
    'allinone'	=> [1, 110],
    'sensu'  => [1, 200],
}

Vagrant.configure("2") do |config|
  config.vm.box = "dummy"
  config.vm.provider :rackspace do |rs|
    rs.username        = "lol"
    rs.api_key         = "lololol"
    rs.flavor          = /2GB/
    rs.image           = /Ubuntu 12.04/
  end
 
  nodes.each do |prefix, (count, ip_start)|
    count.times do |i|
      hostname = "%s" % [prefix, (i+1)]
      config.vm.define "#{hostname}" do |box|
	box.vm.hostname = "#{hostname}.book"
        box.vm.provision :shell, :path => "#{prefix}.sh"
      end
    end
  end
end
