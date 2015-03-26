#
# Cookbook Name:: vpnc
# Recipe:: default
#
# Copyright 2015 Troy Ready
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'base64'

vpnc_ipsec_gateway = node['vpnc']['ipsec_gateway']
vpnc_ipsec_id = node['vpnc']['ipsec_id']
vpnc_ipsec_sec = node['vpnc']['ipsec_secret']
if vpnc_ipsec_sec.start_with?('base64:')
  vpnc_ipsec_sec = Base64.decode64(
    vpnc_ipsec_sec.chomp.reverse.chomp(':46esab').reverse
  )
end
vpnc_user = node['vpnc']['xauth_user']
vpnc_pass = node['vpnc']['xauth_pass']
if vpnc_pass.start_with?('base64:')
  vpnc_pass = Base64.decode64(vpnc_pass.chomp.reverse.chomp(':46esab').reverse)
end

unless node['vpnc']['compile_time']
  case node['platform_family']
  when 'debian'
    package 'vpnc'
  when 'rhel'
    package 'libgcrypt'
    # rubocop:disable Metrics/LineLength
    case node['platform_version'].split('.').first
    when '6'
      remote_file "#{Chef::Config[:file_cache_path]}/vpnc-0.5.3-4.el6.x86_64.rpm" do
        source 'http://dl.fedoraproject.org/pub/epel/6/x86_64/vpnc-0.5.3-4.el6.x86_64.rpm'
        checksum '22e009099b6c587ed9440e1190699cc7a1baa27f84ba9f2999d864bd7b74b1ba'
      end
      rpm_package "#{Chef::Config[:file_cache_path]}/vpnc-0.5.3-4.el6.x86_64.rpm"
    when '5'
      remote_file "#{Chef::Config[:file_cache_path]}/vpnc-0.5.3-8.el5.x86_64.rpm" do
        source 'http://dl.fedoraproject.org/pub/epel/5/x86_64/vpnc-0.5.3-8.el5.x86_64.rpm'
        checksum '050987d54f6f88d39b925d59822b20bbf540bfaa0dab767382c8411e62d0a423'
      end
      rpm_package "#{Chef::Config[:file_cache_path]}/vpnc-0.5.3-8.el5.x86_64.rpm"
    end
    # rubocop:enable Metrics/LineLength
  end

  template '/etc/vpnc/default.conf' do
    sensitive true
    variables vpnc_ipsec_gateway: vpnc_ipsec_gateway,
              vpnc_ipsec_id: vpnc_ipsec_id,
              vpnc_ipsec_sec: vpnc_ipsec_sec,
              vpnc_user: vpnc_user,
              vpnc_pass: vpnc_pass
    source 'vpncdefault.conf.erb'
    mode 0600
    if node['vpnc']['run_as_service'] && File.exist?('/etc/init/vpnc.conf')
      notifies :restart, 'service[vpnc]'
    end
  end

  if node['vpnc']['run_as_service'] &&
     (
       (node['platform'] == 'ubuntu') ||
       node['platform_version'].split('.').first == '6'
     )
    # Keep vpn always running
    # End it with `vpnc-disconnect`
    template '/etc/init/vpnc.conf' do
      source 'upstart-vpnc.conf.erb'
      mode 0644
    end

    service 'vpnc' do
      action :start
    end
  elsif node['vpnc']['run_as_service']
    # TODO: add EL 5 init script
    execute 'vpnc'
  end
else
  # Support legacy cookbooks with vpn network resources needed at compile time.
  # This support will likely be dropped when Chef 13 is released.
  log 'vpnc_compile_deprecated' do
    message 'Deploying vpnc at compile time is deprecated and will likely be dropped when Chef 13 support is added'
    level :warn
    action :nothing
  end.run_action(:write)

  case node['platform_family']
  when 'debian'
    package 'vpnc' do
      action :nothing
    end.run_action(:install)
  when 'rhel'
    package 'libgcrypt' do
      action :nothing
    end.run_action(:install)
    # rubocop:disable Metrics/LineLength
    case node['platform_version'].split('.').first
    when '6'
      remote_file "#{Chef::Config[:file_cache_path]}/vpnc-0.5.3-4.el6.x86_64.rpm" do
        source 'http://dl.fedoraproject.org/pub/epel/6/x86_64/vpnc-0.5.3-4.el6.x86_64.rpm'
        checksum '22e009099b6c587ed9440e1190699cc7a1baa27f84ba9f2999d864bd7b74b1ba'
        action :nothing
      end.run_action(:create)
      rpm_package "#{Chef::Config[:file_cache_path]}/vpnc-0.5.3-4.el6.x86_64.rpm" do
        action :nothing
      end.run_action(:install)
    when '5'
      remote_file "#{Chef::Config[:file_cache_path]}/vpnc-0.5.3-8.el5.x86_64.rpm" do
        source 'http://dl.fedoraproject.org/pub/epel/5/x86_64/vpnc-0.5.3-8.el5.x86_64.rpm'
        checksum '050987d54f6f88d39b925d59822b20bbf540bfaa0dab767382c8411e62d0a423'
      end.run_action(:create)
      rpm_package "#{Chef::Config[:file_cache_path]}/vpnc-0.5.3-8.el5.x86_64.rpm" do
        action :nothing
      end.run_action(:install)
    end
    # rubocop:enable Metrics/LineLength
  end

  template '/etc/vpnc/default.conf' do
    sensitive true
    variables vpnc_ipsec_gateway: vpnc_ipsec_gateway,
              vpnc_ipsec_id: vpnc_ipsec_id,
              vpnc_ipsec_sec: vpnc_ipsec_sec,
              vpnc_user: vpnc_user,
              vpnc_pass: vpnc_pass
    source 'vpncdefault.conf.erb'
    mode 0600
    action :nothing
  end.run_action(:create)

  if node['vpnc']['run_as_service'] &&
     (
       (node['platform'] == 'ubuntu') ||
       node['platform_version'].split('.').first == '6'
     )
    # Keep vpn always running
    # End it with `vpnc-disconnect`
    template '/etc/init/vpnc.conf' do
      source 'upstart-vpnc.conf.erb'
      mode 0644
      action :nothing
    end.run_action(:create)

    service 'vpnc' do
      action :nothing
    end.run_action(:start)
  elsif node['vpnc']['run_as_service']
    # TODO: add EL 5 init script
    execute 'vpnc' do
      action :nothing
    end.run_action(:run)
  end
end
