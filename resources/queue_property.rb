resource_name :queue_property

actions :set
default_action :set

property :file, String, name_property: true
property :value, [String, Integer], required: true

load_current_value do |new_resource|
  current_value = ::DiskCriteo::Utils.check_queue_property(new_resource.file)
  if current_value
    if new_resource.value.is_a? String
      value current_value.to_s
    else
      value current_value
    end
  else
    current_value_does_not_exist!
  end
end

# Set queue property
action :set do
  file = new_resource.file
  value = new_resource.value

  converge_if_changed do
    execute "Set #{value} in #{file}" do
      command "echo #{value} > #{file}"
    end
  end
end
