class Export < ApplicationRecord
  validates :domain, :api_token, :email, presence: true
end
