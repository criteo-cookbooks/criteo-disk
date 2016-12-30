resource_name :partition

actions :create
default_action :create

# Resource properties
property :part_name, String, name_property: true
property :disk, String, required: true
property :size, String, required: true
property :flag, String, required: false
property :file_system, String, required: true
property :mkfs_opts, String, required: false
property :mount_opts, String
property :mount_point, String

load_current_value do |new_resource|
  all_infos = ::DiskCriteo::Utils.scan_existing(node, new_resource.disk)
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
        device lazy { "#{disk}#{::DiskCriteo::Utils.find_part(node, disk, current_resource.part_name)}" }
        action [:umount, :disable]
        not_if { current_resource.mount_point == 'None' }
      end
      ruby_block "Deleting partition #{current_resource.part_name}" do
        block do
          ::DiskCriteo::Utils.destroy_part(node, disk, current_resource.part_name)
        end
        action :run
      end
    end
    # And we recreate it
    todo = flag.nil? ? [:mkpart] : [:mkpart, :setflag]
    parted_disk disk do
      part_type part_name
      part_start lazy { ::DiskCriteo::Utils.find_limits(node, disk, size)[0].to_s }
      part_end lazy { ::DiskCriteo::Utils.find_limits(node, disk, size)[1].to_s }
      flag_name flag
      action todo
    end

    # Format and mount if needed
    to_perform = mount_point.nil? ? [:create] : [:create, :mount, :enable]
    filesystem part_name do
      fstype file_system
      device lazy { "#{disk}#{::DiskCriteo::Utils.find_part(node, disk, part_name)}" }
      mount mount_point
      options mount_opts
      mkfs_options mkfs_opts
      ignore_existing true
      force true
      action to_perform
    end
  end

  converge_if_changed(:mount_point) do
    unless current_resource.nil?
      mount current_resource.mount_point do
        device lazy { "#{disk}#{::DiskCriteo::Utils.find_part(node, disk, current_resource.part_name)}" }
        action [:umount, :disable]
      end
    end
    if mount_point
      directory mount_point do
        recursive true
      end

      mount mount_point do
        device lazy { "#{disk}#{::DiskCriteo::Utils.find_part(node, disk, part_name)}" }
        fstype file_system
        options mount_opts
        action [:mount, :enable]
      end
    end
  end
end
