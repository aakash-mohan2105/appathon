class Export < ApplicationRecord
  validates :domain, :api_key, :email, presence: true
  validates :status, :total_count, :fetch_count, :start_time, presence: true
end