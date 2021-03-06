module DiskCriteo
  # Functions for partition management
  module Utils
    module_function

    def parted_version
      cmd = Mixlib::ShellOut.new('parted --version')
      cmd.run_command.stdout.split($/)[0].scan(/\d\.*/).join.to_f
    end

    def scan_existing(node, disk)
      disk_infos = Mash.new
      cmd = Mixlib::ShellOut.new("parted -m #{disk} unit s print free")
      cmd.run_command
      raise "There is no #{disk} on this server" if cmd.stderr.include?("Could not stat device #{disk}")
      parted_output = cmd.stdout.split($/)
      # On CentOS 6, parted 2.1 only return an error when the disk doesn't have a valid label
      if parted_version <= 2.1
        return nil if parted_output.size.eql?(1) && (parted_output[0] =~ /unrecognised disk label/ ? true : false)
      end
      disk_raw = parted_output[1].split(':')
      part_raw = parted_output[2..-1]
      part = part_raw.map { |t| t.split(':') }.select { |t| !t[4].to_s.eql? 'free;' }
      free_part = part_raw.map { |t| t.split(':') }.select { |t| t[4].to_s.eql? 'free;' }
      partitions = Mash.new
      meta = {
        'physical_block_size' => disk_raw[3],
        'logical_block_size' => disk_raw[4],
        'size' => disk_raw[1]
      }

      meta['meta_part'] = Mash.new
      part.each do |i|
        partitions[(i[5]).to_s] = {
          'size' => i[3],
          'size_in_G' => "#{convert_size(i[3], 'G', meta['logical_block_size'])}G",
          'file_system' => i[4]
        }
        meta['meta_part'][(i[5]).to_s] = {
          'id' => i[0],
          'start' => i[1],
          'stop' => i[2]
        }
      end
      meta['free'] = free_part.map do |i|
        { 'start' => i[1],
          'size' => i[3] }
      end

      # Add mount_point using filesystem ohai
      meta['meta_part'].each do |name, infos|
        dev = "#{disk}#{infos['id']}"
        partitions[name]['mount_point'] = node['filesystem'][dev].nil? ? nil : node['filesystem'][dev]['mount']
      end

      disk_infos['label'] = disk_raw[5]
      disk_infos['partitions'] = partitions
      disk_infos['meta'] = meta
      disk_infos
    end

    # When we use the 'ALL' specific size, we create the partition using [ 0% - 100% ] delimiter.
    # When we do that, parted will automatically align the partition.
    # So the partition size could not be exactly the disk size.
    # That's why we need to use this function.
    def close_to(value, reference, margin = 10_000)
      # We accept a difference of 10000 sectors (around 5M)
      down = value.to_i - margin
      up   = value.to_i + margin
      reference.to_i.between?(down, up)
    end

    # Find sector limits in MB
    def find_limits(node, disk, size)
      # If the size is the word key "ALL", we directly return limits in percent
      return ['0%', '100%'] if size.eql?('ALL')
      alignment = 2048
      infos = scan_existing(node, disk)
      size_sec = convert_size(size, 's', infos['meta']['logical_block_size'])
      # We try to find a matching free part
      start_part = infos['meta']['free'].reject { |i| i['size'].to_i < size_sec.to_i + alignment }.map do |p|
        p['start']
      end.join
      raise 'not enough free space to create the partition' if start_part.empty?
      start_part = start_part.to_i < alignment ? alignment : start_part.to_i + alignment - 1
      end_part = start_part.to_i + size_sec.to_i
      %W(#{start_part}s #{end_part}s)
    end

    def convert_size(value, convert_to, sector_size = nil)
      case value
      when /M$/
        case convert_to
        when /G$/ then value.to_f / 1024
        when /T$/ then value.to_f / 1024 / 1024
        when /s$/ then my_round((value.to_f * 1024 * 1024 / sector_size.to_i))
        end
      when /G$/
        case convert_to
        when /M$/ then (value.to_f * 1024).to_i
        when /T$/ then value.to_f / 1024
        when /s$/ then my_round((value.to_f * 1024 * 1024 * 1024 / sector_size.to_i))
        end
      when /T$/
        case convert_to
        when /G$/ then (value.to_f * 1024).to_i
        when /M$/ then (value.to_f * 1024 * 1024).to_i
        when /s$/ then my_round((value.to_f * 1024 * 1024 * 1024 * 1024 / sector_size.to_i))
        end
      when /s$/
        case convert_to
        when /G$/ then my_round((value.to_f * sector_size.to_i / 1024 / 1024 / 1024))
        when /T$/ then my_round((value.to_f * sector_size.to_i / 1024 / 1024 / 1024 / 1024))
        when /M$/ then my_round((value.to_f * sector_size.to_i / 1024 / 1024))
        end
      else
        raise "Could not convert #{value} to sectors"
      end
    end

    def my_round(value)
      array_value = value.round(1).to_s.split('.')
      array_value[1].eql?('0') ? array_value[0] : value
    end

    def find_part(node, disk, name)
      part_infos = scan_existing(node, disk)['meta']['meta_part']
      part_infos.select { |n| n.eql? name }.map { |_, i| i['id'] }.join || nil
    end

    def umount_part(node, disk, name)
      id = find_part(node, disk, name)
      umount = Mixlib::ShellOut.new("umount #{disk}#{id}")
      umount.run_command
    end

    def destroy_part(node, disk, name)
      id = find_part(node, disk, name)
      Mixlib::ShellOut.new("parted #{disk} --script -- rm #{id}").run_command
    end

    def transform_options(opts, type = 'fs')
      delimiter = type.eql?('mount') ? ',' : ' '
      case opts
      when Hash then opts.map { |k, v| "#{k} " "#{v}" }.join(' ')
      when Array then opts.join(delimiter.to_s)
      when String then opts
      end
    end

    # Use in queue_property resource to load the current value
    def check_queue_property(file)
      raise "Property file #{file} doesn't exist" unless ::File.exists?(file)
      raise "The given property file is a directory (#{file})." if ::File.directory?(file)
      case ::File.basename(file)
      when 'scheduler'
        # We extract the active scheduler
        result = ::File.open(file).readline.match(/.*\[(.+)\].*/)
        result && result[1]
      else
        ::File.open(file).readline.to_i
      end
    end

    def hash_to_path(hash, prepend_string = '' )
      return {} if hash.nil?
      paths_values = Hash.new
      hash.each do |key, value|
        case value
        when Hash
          value.map do |k,v|
            paths_values[::File.join(prepend_string, key, k)] = v
          end
        when String, Integer
          paths_values[::File.join(prepend_string, key )] = value
        end
      end
      return paths_values
    end

  end
end
