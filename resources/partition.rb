resource_name :partition

actions :create
default_action :create

# Idea: for msdos partitions, use part_name to store the partition ID
# (1, 2, 3, or 4) so we can make this idempotent. part_name in msdos
# is useless, but we need a way to know which partition ID is ours if
# it already exists.

# Resource properties
property :part_name, String, name_property: true
property :disk, String, required: true, identity: true
property :device_type, String, default: 'gpt', equal_to: %w[gpt msdos]
property :size, String, required: true
property :flag, String, required: false
property :file_system, String, required: true
property :mkfs_opts, String, required: false
property :mount_opts, String
property :mount_point, String

load_current_value do |new_resource|
  all_infos = ::DiskCriteo::Utils.scan_existing(node, new_resource.disk, new_resource.device_type)
  part_infos = all_infos['partitions'][new_resource.part_name]
  if part_infos
    # We handle the 'ALL' specific size.
    # If we required 'ALL' and we are already close to 'ALL', we set the size to 'ALL'
    if new_resource.size.eql?('ALL')
      if ::DiskCriteo::Utils.close_to(part_infos['size'], all_infos['meta']['size'])
        size 'ALL'
      else
        size part_infos['size_in_G']
      end
    else
      unit = new_resource.size[-1]
      size "#{::DiskCriteo::Utils.convert_size(part_infos['size'], unit, all_infos['meta']['logical_block_size'])}#{unit}"
    end
    file_system part_infos['file_system']
    # we set a "default" value to the mount_point because it can't be nil
    mount = part_infos['mount_point'].nil? ? 'None' : part_infos['mount_point']
    mount_point mount
  else
    current_value_does_not_exist!
  end
end

action :create do
  converge_if_changed(:part_name, :size, :file_system) do
    unless current_resource.nil?
      # We destroy the partition
      Chef::Log.warn('Destroying the existing part')
      # We ensure that the partition is not mounted and enable in the fstab
      mount current_resource.mount_point do
        device(lazy { "#{current_resource.disk}#{::DiskCriteo::Utils.find_part(node, current_resource.disk, current_resource.part_name, new_resource.device_type)}" })
        action %i[umount disable]
        not_if { current_resource.mount_point == 'None' }
      end
      ruby_block "Deleting partition #{current_resource.part_name}" do
        block do
          ::DiskCriteo::Utils.destroy_part(node, current_resource.disk, current_resource.part_name, current_resource.device_type)
        end
        action :run
      end
    end
    # And we recreate it
    size = case new_resource.size
           when 'ALL'
             ::DiskCriteo::Utils.find_all_size(::BlockDevice::Parted.device_table(new_resource.disk))
           else
             ::DiskCriteo::Utils.convert_to_byte(new_resource.size)
           end

    first_offset = lambda do
      free_spaces = ::BlockDevice::Parted.free_spaces(new_resource.disk)
      ::DiskCriteo::Utils.find_first_offset(free_spaces, size)
    end
    case new_resource.device_type
    when 'gpt'
      blockdevice_volume_gpt_partition new_resource.disk do
        partition_name new_resource.part_name
        offset(lazy { @value ||= first_offset.call })
        size size
        flags new_resource.flag
        block_device new_resource.disk
      end
    when 'msdos'
      fs_type = if %w[ntfs linux-swap hfs].include?(new_resource.file_system)
                  new_resource.file_system
                else
                  'ext2'
                end
      blockdevice_volume_msdos_partition new_resource.disk do
        id new_resource.part_name.to_i
        offset(lazy { @value ||= first_offset.call })
        size size
        flags new_resource.flag
        fs_type fs_type
        partition_type 'primary'
        block_device new_resource.disk
      end
    end

    # Format and mount if needed
    to_perform = new_resource.mount_point.nil? ? [:create] : %i[create mount enable]
    filesystem new_resource.part_name do
      fstype new_resource.file_system
      device(lazy { "#{new_resource.disk}#{::DiskCriteo::Utils.find_part(node, new_resource.disk, new_resource.part_name, new_resource.device_type)}" })
      mount new_resource.mount_point
      options new_resource.mount_opts
      mkfs_options new_resource.mkfs_opts
      ignore_existing true
      force true
      action to_perform
    end
  end

  converge_if_changed(:mount_point) do
    unless current_resource.nil?
      mount current_resource.mount_point do
        device(lazy { "#{current_resource.disk}#{::DiskCriteo::Utils.find_part(node, current_resource.disk, current_resource.part_name, new_resource.device_type)}" })
        action %i[umount disable]
      end
    end
    if new_resource.mount_point
      directory new_resource.mount_point do
        recursive true
      end

      mount new_resource.mount_point do
        device(lazy { "#{new_resource.disk}#{::DiskCriteo::Utils.find_part(node, new_resource.disk, new_resource.part_name, new_resource.device_type)}" })
        fstype new_resource.file_system
        options new_resource.mount_opts
        action %i[mount enable]
      end
    end
  end
end
