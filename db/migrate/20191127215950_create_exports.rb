class CreateExports < ActiveRecord::Migration[6.0]
  def change
    create_table :exports do |t|
      t.string :domain
      t.string :api_key
      t.string :email
      # t.string :entity
      t.string :status
      t.bigint :total_count
      t.bigint :fetch_count
      t.bigint :last_fetch_time

      t.timestamps
    end
  end
end
