# This handler generates a gist of the last chef failure, and posts it to an IRC bot on a given TCP port.
# It stores a copy of the last failure on disk, and only generates a new gist if the failure has changed.

# Escape class can be found at https://github.com/akr/escape
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

      # Set path to file containing text dump of last fail
      lastfailfile = "#{Chef::Config[:file_cache_path]}/lastfail"
      
      ignore_hosts = [
        "failinghost.example.com"
      ]

      if ignore_hosts.include?(`hostname -f`.strip)
        return
      end

      # Load the text of the last fail from file if it exists
      lastfailmsg = []
      if File.exists? lastfailfile
          f = File.open(lastfailfile, "r") 
          f.each {|line| lastfailmsg.push line}
      end
      
      # If the new failure is different from the text of the last fail we stored...  
      if !lastfailmsg.drop(1).join.eql? "#{message}\n"
        # gist.rb can be found at http://github.com/defunkt/gist
        gist_command = "gist.rb"
        
        # then generate a gist of it
        gist = %x[#{Escape.shell_command(["echo", "#{message}"])} | /var/chef/handlers/#{gist_command}]
        
        # and write a new last fail file
        File.open(lastfailfile, "w") do |data|
          data.puts "#{gist}"
          data.puts "#{message}"
        end
      else
        # Otherwise, use the gist from the last fail - no need to generate a new one
        gist = lastfailmsg.first
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
