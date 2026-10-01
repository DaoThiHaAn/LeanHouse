# frozen_string_literal: true

Rails.application.config.after_initialize do
  if defined?(SolidQueue)
    # Enable automatic GC compaction on Solid Queue worker startup to reduce memory fragmentation
    SolidQueue.on_start do
      GC.auto_compact = true if GC.respond_to?(:auto_compact=)
    end
  end
end
