require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module LeanHouse
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    #     config.i18n.default_locale = :en
    #
    # Load services
    config.autoload_paths << Rails.root.join("app/services")

    config.i18n.available_locales = [ :en, :vi ]
    config.i18n.default_locale = :vi

    config.time_zone = "Asia/Ho_Chi_Minh"
    config.active_record.default_timezone = :utc

    # Active Record Encryption for PayOS credentials (payos_api_key, payos_checksum_key, payos_client_id).
    # Keys are stored in Rails credentials under active_record_encryption:
    #   primary_key, deterministic_key, key_derivation_salt
    # Generate keys with: bin/rails db:encryption:init
    #
    # Set to false after running: bin/rails payos:encrypt_existing
    config.active_record.encryption.support_unencrypted_data = false

    # Rails wont wrap error fields in <div class="field_with_errors"></div>
    config.action_view.field_error_proc = proc { |html_tag, _instance| html_tag.html_safe }

    config.active_storage.variant_processor = :mini_magick
  end
end
