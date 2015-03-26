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
  package 'vpnc'

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

  if node['vpnc']['run_as_service']
    # Keep vpn always running
    # End it with `vpnc-disconnect`
    template '/etc/init/vpnc.conf' do
      source 'upstart-vpnc.conf.erb'
      mode 0644
    end

    service 'vpnc' do
      action :start
    end
  end
else
  # Support legacy cookbooks with vpn network resources needed at compile time.
  # This support will likely be dropped when Chef 13 is released.
  log 'vpnc_compile_deprecated' do
    message 'Deploying vpnc at compile time is deprecated and will likely be dropped when Chef 13 support is added'
    level :warn
  end

  package 'vpnc' do
    action :nothing
  end.run_action(:install)

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

  if node['vpnc']['run_as_service']
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
  end
end
