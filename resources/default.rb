actions :create
default_action :create

# Resource properties
property :device, String, name_property: true
property :label, String, default: 'gpt', required: true
property :queue_properties, Hash
property :partitions, Hash, required: true

load_current_value do |new_resource|
  disk_infos = ::DiskCriteo::Utils.scan_existing(node, new_resource.device)
  if disk_infos
    label disk_infos['label']
  else
    current_value_does_not_exist!
  end
end

action :create do
  device = new_resource.device
  label = new_resource.label
  partitions = new_resource.partitions

  # Create label
  converge_if_changed :label do
    blockdevice_volume_group device do
      type label
    end
  end

  # We set the queue properties
  property_path = ::File.join('/sys','block', ::File.basename(device), 'queue')
  ::DiskCriteo::Utils.hash_to_path(new_resource.queue_properties, property_path).each do |file, val|
    queue_property file do
      value val
      action :set
    end
  end

  # On CentOS 6, you can't create more than 1 partition per disk.
  # In order to create another partition, it needs to reread the partition table.
  # Since we create,format and mount the partition one by one, the disk is busy when we want to perform the reread.
  # In the future version, we will change the way to create the partitions.
  raise 'CentOS 6 doesn\'t handle more than 1 partition' if partitions.size > 1 && node['platform_version'].to_i < 7

  puts device.inspect

  partitions.each do |part_name, part_infos|
    partition part_name do
      disk device
      device_type label
      size lazy { part_infos['size'] == '-' ? "#{compute_rest_size}B" : part_infos['size'] }
      flag part_infos['flag']
      file_system part_infos['file_system']
      mount_point part_infos['mount_point']
      mount_opts ::DiskCriteo::Utils.transform_options(part_infos['mount_options'], 'mount')
      mkfs_opts ::DiskCriteo::Utils.transform_options(part_infos['mkfs_options'])
      action [:create]
    end
  end
end

action_class do
  def compute_rest_size
    @computed_rest_size ||= begin
                              size_all = ::DiskCriteo::Utils.find_all_size(::BlockDevice::Parted.device_table(new_resource.device))
                              size_assigned = new_resource.partitions.values.reject { |part_infos| part_infos['size'] == '-' }.map { |part_infos| ::DiskCriteo::Utils.convert_size(part_infos['size'], 'B').to_i }.reduce(&:+)
                              size_all - size_assigned
                            end
  end
end
