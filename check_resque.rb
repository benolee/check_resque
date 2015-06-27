#!/usr/bin/env ruby

require "resque"
require "optparse"

options  = {}
required = [:warning, :critical, :host, :queues]

parser   = OptionParser.new do |opts|
  opts.banner = "Usage: check_resque [options]"
  opts.on("-h", "--host redishost", "The hostname of the redis server") do |h|
    options[:host] = h
  end
  opts.on("-n", "--namespace resque:namespace", "The resque namespace") do |n|
    options[:namespace] = n
  end
  opts.on("-q", "--queues low,medium,high", "The queues to check (comma separated)") do |q|
    options[:queues] = q
  end
  opts.on("-w", "--warning percentage", "Warning threshold") do |w|
    options[:warning] = w
  end
  opts.on("-c", "--critical critical", "Critical threshold") do |c|
    options[:critical] = c
  end
end
parser.parse!

if !required.all? { |k| options.has_key?(k) }
  abort parser.to_s
else
  redis = Redis.new(:host => options[:host])
  Resque.redis = redis
  Resque.redis.namespace = options[:namespace]

  queues_to_check = options[:queues].split(",")
  workers = Resque.workers


  status = :ok

  number_of_workers_working_queues_to_check = workers.map(&:queues).count { |queues| queues == queues_to_check }

  warning_range_low, warning_range_high = options[:warning].split(':')
  critical_range_low, critical_range_high = options[:critical].split(':')

  if number_of_workers_working_queues_to_check > warning_range_high.to_i
    status = :warning
  elsif number_of_workers_working_queues_to_check < warning_range_low.to_i
    status = :warning
  elsif number_of_workers_working_queues_to_check > critical_range_high.to_i
    status = :critical
  elsif number_of_workers_working_queues_to_check < critical_range_low.to_i
    status = :critical
  end

  print status.to_s.upcase
  print " - "
  print "#{number_of_workers_working_queues_to_check} of #{options[status]} workers running queues #{options[:queues]}"

  if (status == :critical)
    exit(2)
  elsif status == :warning
    exit(1)
  end
end
