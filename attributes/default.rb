#
# Cookbook Name:: criteo-disk
# Attribute: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

# Example :
# node['criteo_disk'][DEVICE]['label'] = 'gpt'
# node['criteo_disk'][DEVICE]['queue_properties']['scheduler'] = 'noop'
# node['criteo_disk'][DEVICE]['partitions'][NAME]['size'] = '11G'
# node['criteo_disk'][DEVICE]['partitions'][NAME]['id']
# node['criteo_disk'][DEVICE]['partitions'][NAME]['fstype'] = 'ext4'
# node['criteo_disk'][DEVICE]['partitions'][NAME]['mkfs_options']
# node['criteo_disk'][DEVICE]['partitions'][NAME]['flags']
# node['criteo_disk'][DEVICE]['partitions'][NAME]['mount_point'] = '/tmp'
# node['criteo_disk'][DEVICE]['partitions'][NAME]['mount_options'] = 'defaults'
default['criteo_disk'] = {}
