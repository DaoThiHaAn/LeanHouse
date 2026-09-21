class AddPayosOrderCodeSequence < ActiveRecord::Migration[8.1]
  def up
    # Create a dedicated PostgreSQL sequence for PayOS order codes.
    # Starts at 100_000_001 to guarantee 9-digit numbers (matching the
    # previous rand(100_000_000..999_999_999) range) while being atomic
    # and collision-free at the DB level.
    execute "CREATE SEQUENCE payos_order_code_seq START 100000001 INCREMENT 1 NO CYCLE"
  end

  def down
    execute "DROP SEQUENCE IF EXISTS payos_order_code_seq"
  end
end
