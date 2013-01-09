require_relative 'soter/config'
require_relative 'soter/job_worker'

require 'mongo'
require 'mongo_queue'

module Soter

  require 'mongo_queue'

  def self.config
    @config ||= Soter::Config.new
  end

  def self.enqueue(handler, job_params={}, queue_options={})
    options = {'job_params' => job_params, 'queue_options' => queue_options}
    options.merge!({'handler_class' =>  handler.to_s})
    
    if active_at = queue_options.delete(:active_at)
      options.merge!({'active_at' => active_at}) 
    end

    queue.insert(options)
    dispatch_worker
  end

  def self.dequeue(job_params)
    queue.remove('job_params' => job_params)
  end

  private

  def self.database
    @database ||= Mongo::Connection.new
  end

  def self.queue
    @queue ||= Mongo::Queue.new(database, Soter.config.queue_settings)
  end

  def self.workers
    begin
      result = @queue.send(:collection).
        distinct(:locked_by, {:locked_by => {"$ne" => nil}})
    rescue
      result = []
    end

    result || []
  end

  def self.dispatch_worker
    if workers.count < default_workers
      JobWorker.new.start
    else
      queue.cleanup! #remove stuck locks
    end
  end

  def self.default_workers
    Soter.config.workers || 5
  end

end
