require 'spec_helper'
require ::File.join(LIBRARY_DIR, 'diskcriteo_utils')

def generate_table
  num_partitions = rand(1..10)
  start = rand(104_768_000_000)

  Array.new(num_partitions) do
    oldstart = start + 1
    start += rand(2_097_152..104_770_097_152)
    { 'start' => oldstart, 'end' => start }
  end
end

describe ::DiskCriteo::Utils do
  describe 'for find all size methods' do
    let(:table) { ::YAML.load_file(::File.join(SPEC_DATA_DIR, 'device_table.yaml')) }

    it 'computes the max usable size of disk' do
      expect(::DiskCriteo::Utils.find_all_size(table)).to be 5_999_996_960_768
    end

    it 'computes a size aligned with 1MB' do
      5.times do
        expect(::DiskCriteo::Utils.find_all_size(generate_table) % 1024**2).to be 0
      end
    end
  end
end
