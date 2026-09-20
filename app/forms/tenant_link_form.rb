class TenantLinkForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :tel
  attr_accessor :house

  validate :validate_tel_and_tenant

  attr_reader :tenant

  private

  def validate_tel_and_tenant
    return if tel.blank?

    # Check valid tel format
    unless tel.match?(/\A0\d{9}\z/)
      errors.add(
        :tel,
        I18n.t("activerecord.errors.models.user.attributes.tel.invalid")
      )
      return
    end

    # Check registered tenant account
    @tenant = User.find_acc(tel, "tenant")

    unless @tenant
      errors.add(
        :tel,
        I18n.t("errors.tenant_tel_unregistered")
      )
      return
    end

    # Check if the current tenant is already linked
    if @tenant.tenant&.linked?
      current_stay_in_this_house = house&.tenant_stay_for(@tenant.id)
      if current_stay_in_this_house
        location = current_stay_in_this_house.rental_unit&.location_info
        msg = location.present? ?
                I18n.t("errors.tel_linked_current_house_with_location", location: location) :
                I18n.t("errors.tel_linked_current_house")
        errors.add(:tel, msg)
      else
        errors.add(
          :tel,
          I18n.t("errors.tel_linked")
        )
      end
    end
  end
end
