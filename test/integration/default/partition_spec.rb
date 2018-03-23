describe command('parted --machine --script /dev/xvdb -- print') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/(TOOLS|DATA|MISC)/) }
end

describe mount('/media/data') do
  it { should be_mounted }
  its('device') { should eq '/dev/xvdb1' }
  its('type') { should eq 'ext4' }
end

describe filesystem('/media/data') do
  its('size') { should eq 11_222_216 }
end

describe mount('/media/data2') do
  it { should be_mounted }
  its('device') { should eq '/dev/xvdb2' }
  its('type') { should eq 'ext4' }
end

describe filesystem('/media/data2') do
  its('size') { should eq 6_061_632 }
end

describe mount('/media/data3') do
  it { should be_mounted }
  its('device') { should eq '/dev/xvdb3' }
  its('type') { should eq 'ext4' }
end

describe filesystem('/media/data3') do
  its('size') { should eq 1_998_672 }
end

describe mount('/media/msdos_data') do
  it { should be_mounted }
  its('device') { should eq '/dev/xvdc1' }
  its('type') { should eq 'ext4' }
end

describe filesystem('/media/msdos_data') do
  its('size') { should eq 11_222_216 }
end

describe mount('/media/msdos_data2') do
  it { should be_mounted }
  its('device') { should eq '/dev/xvdc2' }
  its('type') { should eq 'ext4' }
end

describe filesystem('/media/msdos_data2') do
  its('size') { should eq 6_061_632 }
end

describe mount('/media/msdos_data3') do
  it { should be_mounted }
  its('device') { should eq '/dev/xvdc3' }
  its('type') { should eq 'ext4' }
end

describe filesystem('/media/msdos_data3') do
  its('size') { should eq 1_998_672 }
end
