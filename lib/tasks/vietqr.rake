namespace :vietqr do
  desc "Sync bank list from VietQR Public API"
  task sync_banks: :environment do
    puts "Syncing banks from VietQR API..."
    synced = Bank.sync_from_vietqr!

    if synced
      puts "Successfully synced #{synced} banks from VietQR."
    else
      puts "Failed to fetch from VietQR. Falling back to default bank data."
      Bank.seed_defaults!
      puts "Loaded #{Bank.count} banks from local defaults."
    end
  end
end
