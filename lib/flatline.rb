require "flatline/version"
require 'logger'
require 'timeout'
require 'aws-sdk'
require 'socket'

module Flatline
  class Flatline
    include Logging # figure this bit out later

    def initialize(opts={})
      log.info 'flatline: starting up!'

      $EXIT = false

      @instance_id = opts['instance_id']
      @services     = opts['services']
      @statsocket = opts['statsocket']
      @deadline     = Time.now + opts['deadline']

      @connection_ok = false
      @current_stats = Array.new


      @monitor = StatsMonitor.new(@services, @statsocket, @deadline)

    end

    def run
      connection_queue = Queue.new
      stats_queue = Queue.new

      bootMonitor = Thread.new do
        until (Time.now >= @deadline || @connection_ok == true)
          @monitor.update
          @connection_ok = @monitor.connection_ok
          @current_stats = @monitor.current_stats
          sleep 10
        end

        if (Time.now >= @deadline && @connection_ok == false)
          #spit out a message, kill the machine
          log.info 'flatline: deadline expired without services connections'
          log.info 'flatline: instance #{@instance_id} is DOA, marking unhealthy'
          # mark unhealthy
          # exit program
        else
          log.info 'flatline: instance #{@instance_id} is OKAY, switching to healthcheck'
        end
      end

      bootMonitor.join()



      healthMonitor = Thread.new do
        loop do
          @monitor.update
          connection_queue << @monitor.connection_ok
          stats_queue << @monitor.current_stats
          sleep 10
        end
      end

      healthReport = Thread.new do


    end


  end

  class StatsMonitor
    include Logging
    attr_accessor connection_ok, current_stats

    def initialize(services=[], statsocket, deadline)
      log.info 'flatline: initializing statsmonitor'
      @services = services
      @statsocket = statsocket
      @connection_ok = false
      @current_stats = Array.new
      @deadline = deadline
      log.info 'flatline: statsmonitor init complete'
    end

    def run()


    end

    def update()
      begin
        s = UNIXSocket.new(@statsocket)
        s.write "show stat\n"
        info = s.read()
        s.close()
      rescue StandardError => e
        log.warn "flatline: unhandled error reading stats socket: #{e.inspect}"
        return
      end

      @current_stats = Array.new
  
      entries = info.split("\n")
      entries.each do |entry|
        fields = entry.split(",")
        next if ['FRONTEND', 'BACKEND'].include?(fields[1])

        if @services.include?(fields[0]) 
          if fields[17] == "UP"
            @connection_ok = true
          else
            @connection_ok = false
          end
  
          hash_stats = {:service => fields[0], :address => fields[1], :state => fields[17]}
          @current_stats.push(hash_stats)
        end
      end


    end
  end

  class HealthReporter
    include Logging
    attr_accessor connection_ok, current_stats

    def initialize()
      @connection_ok = false
      @current_stats = Array.new

      @server = TCPServer.new 2000 # Server bound to port 2000
    end

    def update()




    def run()


      

      loop do
        socket = server.accept    # Wait for a client to connect

        request = socket.gets


        log.info "flatline: got healthcheck -- #{request}"

        response = "Hello World!\n"


        socket.print "HTTP/1.1 200 OK\r\n" +
             "Content-Type: text/plain\r\n" +
             "Content-Length: #{response.bytesize}\r\n" +
             "Connection: close\r\n"

        # Print a blank line to separate the header from the response body,
        # as required by the protocol.
        socket.print "\r\n"

        # Print the actual response body, which is just "Hello World!\n"
        socket.print response

        # Close the socket, terminating the connection
        socket.close
      end
    end
  end


  module Logging
    # shamelessly taken from log.rb in Airbnb's Nerve application
    def log
      @logger ||= Logging.logger_for(self.class.name)
    end

    # Use a hash class-ivar to cache a unique Logger per class:
    @loggers = {}

    class << self
      def logger_for(classname)
        @loggers[classname] ||= configure_logger_for(classname)
      end

      def configure_logger_for(classname)
        logger = Logger.new(STDERR)
        logger.level = Logger::INFO unless ENV['DEBUG']
        logger.progname = classname
        return logger
      end
    end
  end



  # Your code goes here...
end
