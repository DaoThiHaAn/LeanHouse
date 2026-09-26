class TransferNoteBuilder
  DEFAULT_TEMPLATE = "{invoice_code}".freeze

  def self.build(template, invoice)
    tpl = template.presence || DEFAULT_TEMPLATE
    vars = {
      "{room_name}"     => invoice.room ? invoice.room.name : nil,
      "{house_name}"    => invoice.house.name,
      "{invoice_code}"  => invoice.code,
      "{month}"         => invoice.billing_month.strftime("%m"),
      "{tenant_name}"   => invoice.tenant ? invoice.tenant.user.fullname : nil,
      "{note}"          => invoice.note
    }

    result = tpl.dup
    vars.each do |tag, val|
      result = result.gsub(tag, val.to_s)
    end

    sanitize(result)
  end

  def self.sanitize(text)
    return "" if text.blank?

    # Decompose Unicode diacritics, strip accents, remove non-alphanumeric/hyphen/space, uppercase
    text.to_s
        .unicode_normalize(:nfd)
        .gsub(/[\u0300-\u036f]/, "")
        .gsub(/[đĐ]/, "d")
        .gsub(/[^0-9A-Za-z -]/, "")
        .squish
        .upcase[0..49]
  end
end
