require 'faraday'

module ExportClient
  class Client
    attr_accessor :domain, :email, :api_key, :api_client, :logger, :start_time, :raw_data_file
    def initialize(domain_name, email_address, token, start)
      self.domain = domain_name
      self.email = email_address
      self.api_key = token
      self.start_time = if @export
                          @export['start_time']
                        else
                          start
                        end
      self.logger = ActiveSupport::Logger.new(STDOUT)
      self.raw_data_file = File.open("#{domain}_tickets.json", 'w+')

      @stop = false
      @pause = false
      self.api_client = Faraday.new("https://#{domain}.zendesk.com/api/v2") do |config|
        config.adapter  Faraday.default_adapter
        config.basic_auth(email.to_s + '/token', api_key)
      end
    end

    def pause_export
      @pause = true
    end

    def stop_export
      @stop = true
    end

    def fetch(id)
      @export = Export.find_by_id(id)
      fetch_tickets
      close_all_files
    end

    def fetch_tickets
      begin
        url = '/tickets.json?start_time=1332034771'
        count = 0
        total_count = 1
        response = ''
        while !@stop || !@pause || count < total_count
          response = api_client.get(url)
          handle_response(response)
          byebug
          copy_data_to_file(response.body['tickets'])
          total_count = response.body['count']
          count += response.body['tickets'].size
          @export.update_attribute(:total_count, total_count)
          @export.update_attribute(:fetch_count, count)
          url = response.body['next_page']
        end
        if @pause
          last_fetch_time = response.body['tickets'].last['created_at']
          @export.update_attribute(:start_time, DateTime.now.strftime(last_fetch_time))
          @export.update_attribute(:status, 'paused')
        elsif @stop
          @export.update_attribute(:start_time, nil)
          @export.update_attribute(:status, 'stopped')
        end
      rescue StandardError => e
        logger.error(e.message)
        logger.error(response.body)
        @stop = true
      end
    end

    def handle_response(response)
      case response.status
        when 200..399
          return
        else
          @stop = true
          raise StandardError.new response.body
      end
    end

    def copy_data_to_file tickets
      latest_ticket_id_hash = {}
      tickets.each do |ticket|
        if @previous_ticket_id_hash
          updated_at = @previous_ticket_id_hash[ticket['id']]
          next if ticket['updated_at'] == updated_at
        end
        raw_data_file.puts ticket.to_json
        latest_ticket_id_hash[ticket['id']] = ticket['updated_at']
      end
      @previous_ticket_id_hash = latest_ticket_id_hash
    end

    def close_all_files
      raw_data_file.close
      byebug
      @export.update_attribute(status, 'completed')
    end
  end
end