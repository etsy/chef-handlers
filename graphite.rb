require "chef"
require "chef/handler"
require "socket"

## this is based on https://github.com/imeyer/chef-handler-graphite
## with host specific metrics and graphite-simple dep removed

class GraphiteReporting < Chef::Handler
  attr_writer :metric_key, :graphite_host, :graphite_port

  def initialize(options = {})
    @metric_key    = "chef.runs"
    @graphite_host = "graphite.example.com"
    @graphite_port = "2003"
  end

  def report
    Chef::Log.debug("graphite_handler loaded as a handler")

    metrics = Hash.new
    metrics[:updated_resources] = run_status.updated_resources.length
    metrics[:all_resources] = run_status.all_resources.length
    metrics[:elapsed_time] = run_status.elapsed_time
    metrics[:success] = run_status.success? ? 1 : 0;
    metrics[:fail] = run_status.success? ? 0 : 1;

    metrics.each do |metric, value|
      time = Time.now
      graphite_line = "#{@metric_key}.#{node[:hostname]}.#{metric} #{value} #{time.to_i}\n"
      Chef::Log.debug(graphite_line)

      s = TCPSocket.new(@graphite_host,@graphite_port)
      s.write(graphite_line)
      s.close

    end

  end
end
