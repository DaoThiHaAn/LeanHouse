class Bank < ApplicationRecord
  has_many :bank_accounts, dependent: :restrict_with_error

  validates :name, :code, :bin, :short_name, presence: true
  validates :bin, uniqueness: true
  validates :code, uniqueness: true

  scope :sorted, -> { order(short_name: :asc) }
  scope :payos_supported, -> { where(bin: BankAccount::PAYOS_SUPPORTED_BINS).or(where(code: BankAccount::PAYOS_SUPPORTED_CODES)) }

  def self.seed_defaults!
    data_file = Rails.root.join("db/data/banks.json")
    return unless File.exist?(data_file)

    banks_data = JSON.parse(File.read(data_file))
    transaction do
      banks_data.each do |b|
        next if b["bin"].blank? || b["code"].blank?

        bank = find_or_initialize_by(bin: b["bin"])
        bank.name = b["name"]
        bank.code = b["code"]
        bank.short_name = b["short_name"] || b["code"]
        bank.logo_url = b["logo_url"]
        bank.save!
      end
    end
  rescue ActiveRecord::RecordNotUnique
    # Handled if another process seeded concurrently
  end

  def self.sync_from_vietqr!
    require "net/http"
    require "json"
    require "uri"

    uri = URI("https://api.vietqr.io/v2/banks")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    return false unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)["data"] || []
    synced_count = 0

    transaction do
      data.each do |b|
        next if b["bin"].blank? || b["code"].blank?

        bank = find_or_initialize_by(bin: b["bin"])
        bank.name = b["name"]
        bank.code = b["code"]
        bank.short_name = b["shortName"] || b["code"]
        bank.logo_url = b["logo"]
        bank.save!
        synced_count += 1
      end
    end

    Rails.logger.info("Successfully synced #{synced_count} banks from VietQR.")
    synced_count
  rescue StandardError => e
    Rails.logger.error("Error during VietQR bank sync: #{e.message}")
    false
  end

  def display_name
    "#{short_name} - #{name}"
  end

  def payos_supported?
    BankAccount::PAYOS_SUPPORTED_BINS.include?(bin.to_s) ||
      BankAccount::PAYOS_SUPPORTED_CODES.include?(code.to_s.upcase)
  end
end
