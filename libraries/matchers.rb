if defined?(ChefSpec)

  def create_criteo_disk(resource)
    ChefSpec::Matchers::ResourceMatcher.new(:criteo_disk, :create, resource)
  end

  def create_partition(resource)
    ChefSpec::Matchers::ResourceMatcher.new(:partition, :create, resource)
  end
end
