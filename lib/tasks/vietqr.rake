namespace :vietqr do
  desc "Sync bank list from VietQR Public API"
  task sync_banks: :environment do
    require "net/http"
    require "json"
    require "uri"

    uri = URI("https://api.vietqr.io/v2/banks")
    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)["data"] || []
        count = 0
        data.each do |b|
          next if b["bin"].blank? || b["code"].blank?

          bank = Bank.find_or_initialize_by(bin: b["bin"])
          bank.name = b["name"]
          bank.code = b["code"]
          bank.short_name = b["shortName"] || b["code"]
          bank.logo_url = b["logo"]
          bank.save!
          count += 1
        end
        puts "Successfully synced #{count} banks from VietQR."
      else
        puts "Failed to fetch from VietQR: #{response.code} #{response.message}"
      end
    rescue StandardError => e
      puts "Error during bank sync: #{e.message}"
    end
  end
end
