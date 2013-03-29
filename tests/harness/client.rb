#!/usr/bin/ruby
# RJR test harness client

require 'rubygems'
require 'optparse'
require 'rjr'

require 'common'

RJR::Logger.log_level = ::Logger::DEBUG

##########################################################


MAX_MESSAGES   =  5 # only used when generating random number of messages
MAX_INTERVAL   = 20 # only used when generating random interval
MAX_DISCONNECT = 30 # only used when generating random disconnect

config = { :mode       =>                    :msg,
           :node_id    =>       'rjr_test_client',
           :transport  =>                   :amqp,
           :broker     =>             'localhost',
           :dst        => 'rjr_test_server-queue',
           :num_msg    =>                       1,
           :msg_id     =>                   :rand,
           :block      =>                   false,
           :interval   =>                       0,
           :disconnect =>                   false}

optparse = OptionParser.new do |opts|
  opts.on('-h', '--help', 'Display this help screen') do
    puts opts
    exit
  end

  opts.on('-m', '--mode mode', 'Mode of operation, default "msg" to send message, may be "rand" to send sequences of random bytes') do |mode|
    config[:mode] = mode.intern
  end

  opts.on('-i', '--id ID', 'Node ID to assign to client') do |id|
    config[:node_id] = id
  end

  opts.on('-t', '--transport type', 'Type of transport to connect to server') do |t|
    config[:transport] = t.intern
  end

  opts.on('-b', '--broker broker', 'AMQP Broker (only needed if transport is amqp)') do |b|
    config[:broker] = b
  end

  opts.on('--dst  dst', 'Destination which to connect to/send messages to') do |dst|
    config[:dst] = dst
  end

  opts.on('-r', '--[no-]return', 'Boolean indicating if client should block/wait for server messages (default false)') do |ret|
    config[:block] = !ret
  end

  opts.on('-n', '--num number_of_messages', 'Number of messages to send to server (may be :rand or indefinite)') do |n|
    config[:num_msg] = case n.to_s.intern
                       when :rand       then rand(MAX_MESSAGES)
                       when :indefinite then 1000000000 # XXX 'indefinite ;-)'
                       else n.to_i
                       end
  end

  opts.on('--message ID', 'Message to send to server (rand to select random)') do |mid|
    config[:msg_id] = mid
  end

  opts.on('--interval seconds', 'Number of seconds after which to wait between requests (or rand)') do |s|
    config[:interval] = s.to_s.intern
  end

  opts.on('-d', '--disconnect seconds', OptionParser::DecimalNumeric, 'Number of seconds after which to disconnect client (or rand)') do |d|
    config[:disconnect] = d.to_s.intern
  end
end

optparse.parse!

if config[:num_msg] < 1
  puts "At least one message must be specified"
  exit 1
end

##########################################################

NODES = {config[:transport] => {:node_id    => config[:node_id],
                                :broker     => config[:broker], # XXX only needed for amqp
                                :keep_alive => true} }          # conditionally set keep alive?

METHODS_DIR  = File.join(File.dirname(__FILE__), 'methods')

MESSAGES_DIR = File.join(File.dirname(__FILE__), 'messages')

##########################################################

node = RJRNode.new(NODES)
RJRMethods.load(METHODS_DIR, 'client_')
RJRMessages.load(MESSAGES_DIR)

if config[:disconnect]
  disconnect_thread = Thread.new {
    seconds = config[:disconnect] == :rand ? rand(MAX_DISCONNECT) : config[:disconnect].to_s.to_i
    sleep seconds
    # node.halt ?
    exit 1
  }
end

# invoke request(s)
0.upto(config[:num_msg]-1) { |i|
  # TODO implement mode == :rand

  # grab message (or rand message)
  msg = (config[:msg_id] == :rand ? RJRMessages.rand_msg : RJRMessages.get(config[:msg_id]))

  if msg.nil?
    puts "Invalid message id"
    exit 1
  end

  # manipulate msg params
  params = msg[:params].collect { |p| p.gsub('<CLIENT_ID>', config[:node_id]) } # TODO other substitutions

  # invoke request
  res = node.invoke_request(config[:dst], msg[:method], *params)

  # verify and output result
  ress = (msg[:result].nil? ? "" : (msg[:result].call(res) ? "passed" : "failed"))
  RJR::Logger.info "#{msg[:method]} result #{res} #{ress}"

  if msg[:interval] && i < (config[:num_msg] - 1)
    sleep(msg[:interval] == :rand ? rand(MAX_INTERVAL) : msg[:interval].to_s.to_i)
  end
}

node.join if config[:block]
