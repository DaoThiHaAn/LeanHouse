class TransferNoteBuilder
  DEFAULT_TEMPLATE = "{room_name} {invoice_code}".freeze

  def self.build(template, invoice)
    tpl = template.presence || DEFAULT_TEMPLATE
    vars = {
      "{room_name}"     => invoice.room.name,
      "{house_name}"    => invoice.house.name,
      "{invoice_code}"  => invoice.code,
      "{month}"         => invoice.billing_month.strftime("%m"),
      "{tenant_name}"   => invoice.tenant&.user&.fullname,
      "{note}"          => invoice.note
    }

    result = tpl.dup
    vars.each do |tag, val|
      result = result.gsub(tag, val.to_s)
    end

    # Concat invoice note if not already included in template and present
    if !tpl.include?("{note}") && invoice.note.present?
      result = "#{result} #{invoice.note}"
    end

    # Transliterate Vietnamese accents, remove special chars, uppercase and truncate to 50 chars for bank transfer compliance
    clean = I18n.transliterate(result)
    clean.gsub(/[^0-9A-Za-z ]/, "").squish.upcase[0..49]
  end
end
