# This file is auto-generated by the code_generator (one-time action)
#
# Cookbook Name:: criteo-disk
# Spec:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.

require 'spec_helper'

## Variables declaration
# OS version to test
os_version = ['6.7', '7.2.1511']
# Disk to create
disk = '/dev/sdb'
# Expected parted output
parted_part_output ="BYT;
#{disk}:41943040s:scsi:512:512:gpt:ATA VBOX HARDDISK;
1:34s:41943006s:41942973s:free;"
# Partitions declaration
# On CentOS6, we only support 1 partition per disk.
# So we merge these two variables only on centOS7.
part1 = {
  'DATA' => {
    'size' => '12G',
    'file_system' => 'ext4',
    'mount_point' => '/media/data',
    'mount_options' => ['noatime', 'nobarrier', 'data=writeback', 'noauto_da_alloc'],
    'mkfs_options' => {
      '-O' => 'uninit_bg',
      '-m' => 0,
      '-E' => 'lazy_itable_init=1'
    }
  }
}
part2 = {
  'DATA2' => {
    'size' => '5G',
    'file_system' => 'ext4',
    'mount_point' => '/media/data2',
    'mount_options' => ['noatime', 'nobarrier', 'data=writeback', 'noauto_da_alloc'],
    'mkfs_options' => {
      '-O' => 'uninit_bg',
      '-m' => 0,
      '-E' => 'lazy_itable_init=1'
    }
  }
}

describe 'criteo-disk::default' do
  os_version.each do |v|
    # On CentOS 6, we only deal with 1 partition
    partitions = v.eql?('7.2.1511') ? part1.merge(part2) : part1
    parted_version = v.eql?('6.7') ? 'parted (GNU parted) 2.1' : 'parted (GNU parted) 3.2'

    context "With #{partitions.size} partition(s) on Centos #{v}" do
      before(:each) do
        expect_shellout('parted -m /dev/sdb unit s print free', stdout: parted_part_output)
        expect_shellout('parted --version', stdout: parted_version)
      end
      let(:chef_run) do
        ::ChefSpec::SoloRunner.new(platform:  'centos',
                                 version:   v,
                                 step_into: ['criteo_disk']) do |node|
          node.normal['criteo_disk'][disk]['partitions'] = partitions
          node.normal['criteo_disk'][disk]['label'] = 'gpt'
        end.converge(described_recipe)
      end

      it "creates disk #{disk}" do
        expect(chef_run).to create_criteo_disk(disk)
      end

      partitions.keys.each do |part|
        it "creates partition #{part}" do
          expect(chef_run).to create_partition part
        end
      end
    end
  end
end
