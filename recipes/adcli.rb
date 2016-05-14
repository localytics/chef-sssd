# Cookbook Name:: sssd
# Recipe:: adcli
#
# Copyright (C) 2015 Localytics
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

adcli_rpm = "#{Chef::Config[:file_cache_path]}/#{node['sssd']['adcli']['rpm']}"

remote_file adcli_rpm do
  source node['sssd']['adcli']['rpm_source']
end

package 'adcli' do
  source adcli_rpm
end
