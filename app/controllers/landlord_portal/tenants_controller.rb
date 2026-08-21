class LandlordPortal::TenantsController < LandlordPortal::BaseController
  layout "house_mngment"

  before_action :authorize_tenant_belongs_to_house!, only: [ :move, :destroy ]

  def show
    render :show
  end

  def index
    return render :no_tenant if @house.occupied_slots.zero?

    @signed_tenants = @house.all_linked_tenants(signed_contract: true)
    @unsigned_tenants = @house.all_linked_tenants(signed_contract: false)
    render :index
  end

  #  Return the filtered table partial
  def filtered
    @tenants = TenantFilter.call(house: @house, params: params)

    render partial: "tenant_table",
          locals: { signed_tenants: @tenants, house: @house }
  end

  # TODO: Modal form to move tenant to another rental unit
  def move
    @available_slots = AvailableSlotsService.call(
      house: @house,
      excluded_rental_unit_id: @tenant_stay.rental_unit_id
    )
  end

  def execute_move
    TenantMover.call(
      house: @house,
      tenant_stay: @tenant_stay,
      rental_unit_id: params.expect(:rental_unit_id)
    )
    redirect_to landlord_house_tenants_path(@house), notice: t("success_messages.tenant_moved")
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    redirect_to landlord_house_tenants_path(@house), alert: t("errors.rental_unit_unavailable")
  end

  def new
    @form = TenantLinkForm.new
  end

  def available
    @form = TenantLinkForm.new(tenant_params)

    if @form.valid?
      @tenant = @form.tenant
      @available_slots = AvailableSlotsService.call(house: @house)

      render turbo_stream: turbo_stream.replace(
          "tenant_form",
          template:  "landlord_portal/tenants/extended_new")
    else
      render :new, status: :unprocessable_entity
    end
  end

  # TODO:
  def create_new
    @user = User.new
    @available_slots = AvailableSlotsService.call(house: @house)
  end

  # Link a tenant to a rental unit
  def create
    Checkin.call(
      house: @house,
      tenant_id: params.expect(:tenant_id),
      rental_unit_id: params.expect(:rental_unit_id)
    )

    redirect_to landlord_house_tenants_path(@house), notice: t("success_messages.tenant_linked")
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    redirect_to new_landlord_house_tenant_path(@house), alert: t("errors.rental_unit_unavailable")
  end

  # Remove a tenant from a house
  def destroy
    Checkout.call(
      house: @house,
      tenant_stay: @tenant_stay
    )

    redirect_to landlord_house_tenants_path(@house),
              notice: t("success_messages.tenant_removed")
  end

  private

  def tenant_params
    params.expect(tenant_link_form: [ :tel ])
  end

  def authorize_tenant_belongs_to_house!
    @tenant_stay = @house.tenant_stay_for(params[:id])
    raise CanCan::AccessDenied unless @tenant_stay
    @tenant = @tenant_stay.tenant
  end

  # def prepare_available_slots
  #   @rental_units = @house.available_rental_units.to_a
  #   @rooms = @rental_units.filter_map(&:room).uniq

  #   @floors = @rooms
  #     .filter_map(&:floor)
  #     .uniq
  #     .sort_by(&:position)

  #   @room_options =
  #     if @house.room?
  #       @rental_units.map do |unit|
  #         room = unit.rentable

  #         {
  #           id: room.id,
  #           floorId: room.floor_id,
  #           name: room.name,
  #           rentalUnitId: unit.id
  #         }
  #       end
  #     else
  #       @rooms.map do |room|
  #         {
  #           id: room.id,
  #           floorId: room.floor_id,
  #           name: room.name,
  #           rentalUnitId: nil
  #         }
  #       end
  #     end

  #   @bed_options =
  #     if @house.bed?
  #       @rental_units.map do |unit|
  #         bed = unit.rentable

  #         {
  #           id: bed.id,
  #           roomId: bed.room_id,
  #           name: bed.name,
  #           rentalUnitId: unit.id
  #         }
  #       end
  #     else
  #       []
  #     end
  # end
end
