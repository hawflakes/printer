require "data_store"
require "print_queue"
require "print_processor"
require "print_archive"

class RemotePrinter
  def self.find(id)
    new(id)
  end

  def self.find_by_ip(ip)
    ip_key = "ip:#{ip}"
    now = Time.now.to_i
    DataStore.redis.zremrangebyscore(ip_key, 0, now-60)
    ids = DataStore.redis.zrangebyscore(ip_key, now-60, now)
    ids.map { |id| find(id) }
  end

  attr_reader :id

  def initialize(id)
    @id = id
  end

  def update(params)
    DataStore.redis.hset(key, "type", params[:type])
    now = Time.now.to_i
    ip_key = "ip:#{params[:ip]}"
    DataStore.redis.zadd(ip_key, now, id)
  end

  def type
    DataStore.redis.hget(key, "type")
  end

  def width
    PrintProcessor.for(type).width
  end

  def data_to_print
    print_info = queue.pop
    if print_info
      print = archive.find(print_info["print_id"])
      if print
        data = {"width" => print.width, "height" => print.height, "pixels" => print.pixels}
        PrintProcessor.for(type).process(data)
      end
    end
  end

  def add_print(data)
    print = archive.store(data)
    queue.enqueue(print_id: print.id)
  end

  private

  def queue
    PrintQueue.new(id)
  end

  def archive
    PrintArchive.new(id)
  end

  def key
    "printers:#{id}"
  end
end