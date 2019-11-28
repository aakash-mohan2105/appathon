require 'zendesk_api'

module ExportClient
  class Client
    attr_accessor :domain, :email, :token, :api_client, :logger, :start_time, :raw_data_file
    def initialize(export_object)
      self.domain = export_object[domain]
      self.email = export_object[email]
      self.token = export_object[token]
      self.start_time = export_object[start_time]
      self.logger = ActiveSupport::Logger.new(STDOUT)
      self.raw_data_file = File.open("#{domain}_tickets.json", 'w+')

      @stop = false
      @pause = false
      self.api_client = ZendeskAPI::Client.new do |config|
        config.url = "https://#{domain}.zendesk.com/api/v2"
        config.username = email
        config.token = token
        config.retry = true
        config.logger = logger
        config.cache = false
      end
    end

    def pause_export
      @pause = true
    end

    def stop_export
      @stop = true
    end

    def fetch
      fetch_tickets
      close_all_files
    end

    def fetch_tickets
      begin
        tickets = ZendeskAPI::Ticket.incremental_export(api_client, start_time)
        loop do
          copy_data_to_file(tickets.fetch!)
          break if @stop || @pause
          tickets.next
        end
        if @pause
          last_fetch_time = tickets.last['created_at']
          @export.update_attribute(last_fetch_time: DateTime.now.strftime(last_fetch_time))
          @export.update_attribute(status: 'paused')
        elsif @stop
          @export.update_attribute(last_fetch_time: nil)
          @export.update_attribute(status: 'stopped')
        end
      rescue ZendeskAPI::Error::NetworkError, ZendeskAPI::Error::RecordNotFound => e
        logger.ERROR(e.message)
        logger.ERROR(e.message.body)
        @stop = true
      end
    end

    def copy_data_to_file tickets
      latest_ticket_id_hash = {}
      tickets.map do |ticket|
        # Assignee and requester are eager loaded.Can be exported along with it
        logger.INFO("#{ticket['id']}, 'Skipping tkt:: Deleted") && next if ticket['status'] == 'deleted'.freeze
        if @previous_ticket_id_hash
          updated_at = @previous_ticket_id_hash[ticket['id']]
          logger.INFO("#{ticket['id']}, 'Skipping tkt:: Duplicate") && next if ticket['updated_at'] == updated_at
        end
        raw_data_file.puts ticket.to_json
        latest_ticket_id_hash[ticket['id']] = ticket['updated_at']
      end
      @previous_ticket_id_hash = latest_ticket_id_hash
    end

    def close_all_files
      raw_data_file.close
      @export.update_attribute(status: :completed)
    end
  end
end