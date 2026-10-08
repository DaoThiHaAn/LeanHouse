class SeedInitialBanks < ActiveRecord::Migration[8.0]
  def up
    return if Rails.env.test?

    Bank.seed_defaults! if Bank.none?
  end

  def down
    # No-op to avoid breaking existing bank accounts
  end
end
