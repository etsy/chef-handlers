require 'escape'
require 'socket'

module Etsy
  class LogToIRC < Chef::Handler

    def report
      # The Node is available as +node+
      subject = "Chef run failed on #{node.name}\n"
      # +run_status+ is a value object with all of the run status data
      message = "#{run_status.formatted_exception}\n"
      # Join the backtrace lines. Coerce to an array just in case.
      message << Array(backtrace).join("\n")

      lastfailfile = "#{Chef::Config[:file_cache_path]}/lastfail"
      
      ignore_hosts = [
        "failinghost.example.com"
      ]

      if ignore_hosts.include?(`hostname -f`.strip)
        return
      end

      lastfailmsg = []
      if File.exists? lastfailfile
          f = File.open(lastfailfile, "r") 
          f.each {|line| lastfailmsg.push line}
      end
        
      if !lastfailmsg.drop(1).join.eql? "#{message}\n"
        # gist.rb can be found at http://github.com/defunkt/gist
        gist_command = "gist.rb"
        gist = %x[#{Escape.shell_command(["echo", "#{message}"])} | /var/chef/handlers/#{gist_command}]
        
        File.open(lastfailfile, "w") do |data|
          data.puts "#{gist}"
          data.puts "#{message}"
        end
      else
        gist = lastfailmsg.first
      end

      File.open("#{Chef::Config[:file_cache_path]}/lastfaildebug", "w") do |data|
          data.puts "#{gist}"
          data.puts "#{message.inspect}"
          data.puts "\n\n\n"
          data.puts "#{lastfailmsg.first}"
          data.puts "#{lastfailmsg.drop(1).join.inspect}"
      end
        
      # Color code
      subject = subject.sub('failed', '#BOLD#REDfailed#NORMAL')
      subject = subject.sub(/([a-z0-9]*\..*)/, '#BOLD#ORANGE\1#NORMAL')

      # Initiate TCP session with ircbot (we use irccat... see https://github.com/RJ/irccat)
      t = TCPSocket.new("ircbot.example.com", "12345")
      t.puts("#chef #{subject}\n#BOLD#BLUE#{gist}#NORMAL")
      t.close

    end
  end
end
