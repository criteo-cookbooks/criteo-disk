require 'chefspec'
require 'chefspec/berkshelf'

def expect_shellout(cmd, opts = {})
  simulate_failure = opts[:simulate_failure]
  double(cmd).tap do |d|
    expect(Mixlib::ShellOut).to receive(:new).with(cmd).and_return(d).at_least(1).times
    expect(d).to receive(:run_command).and_return(d).at_least(1).times

    allow(d).to receive(:command).and_return(cmd)
    allow(d).to receive(:stdout).and_return(opts[:stdout] || '')
    allow(d).to receive(:stderr).and_return(opts[:stderr] || '')

    allow(d).to receive(:error?).and_return(simulate_failure)
    allow(d).to receive(:error!) {
      raise Mixlib::ShellOut::ShellCommandFailed, "#{cmd} failed!" if simulate_failure
    }
  end
end