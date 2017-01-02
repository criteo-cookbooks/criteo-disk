#
# Cookbook Name:: criteo-disk
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

# This recipe will install parted
include_recipe 'parted::default'

node['criteo_disk'].each do |device, opts|
  criteo_disk device do
    label opts['label']
    queue_properties opts['queue_properties']
    partitions opts['partitions']
    action :create
  end
end
