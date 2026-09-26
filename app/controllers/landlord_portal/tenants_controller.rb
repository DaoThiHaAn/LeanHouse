class LandlordPortal::TenantsController < LandlordPortal::BaseController
  layout "house_mngment"

  before_action :authorize_tenant_belongs_to_house!, only: [ :show, :move, :destroy, :execute_move, :confirm_remove ]
  before_action :check_house_non_full, only: [ :new, :create_new, :available ]

  def show
    @user = @tenant.user
    @latest_contract = @house.contracts.where(tenant: @tenant).latest_started.first || @tenant.latest_contract
  end

  def index
    return render :no_tenant if @house.occupied_slots.zero?

    @stats = @house.tenant_summary_stats
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

  def confirm_remove
    # renders confirm_remove.html.erb inside the remove_tenant_modal turbo frame
  end

  # Modal form to move tenant to another rental unit
  def move
    @available_slots = AvailableSlotsBuilder.call(
      house: @house,
      excluded_rental_unit_id: @tenant_stay.rental_unit_id
    )
  end

  def execute_move
    TenantMover.call(
      house: @house,
      tenant_stay: @tenant_stay,
      rental_unit_id: params.expect(:rental_unit_id),
      end_contract: params[:end_contract] == "1"
    )

    @house.reload
    @tenant.reload
    @stats = @house.tenant_summary_stats
    @unsigned_tenants = @house.all_linked_tenants(signed_contract: false)
    flash.now[:notice] = t("success_messages.tenant_moved")

    respond_to do |format|
      format.html { redirect_to landlord_house_tenants_path(@house), notice: t("success_messages.tenant_moved") }
      format.turbo_stream
    end
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    flash.now[:alert] = t("errors.rental_unit_unavailable")
    respond_to do |format|
      format.html { redirect_to landlord_house_tenants_path(@house), alert: flash.now[:alert] }
      format.turbo_stream { render :move_error, status: :unprocessable_entity }
    end
  end

  def new
    @form = TenantLinkForm.new(house: @house)
  end

  def available
    @form = TenantLinkForm.new(tenant_params)
    @form.house = @house

    if @form.valid?
      @tenant = @form.tenant
      @available_slots = AvailableSlotsBuilder.call(house: @house)

      render turbo_stream: turbo_stream.replace(
          "tenant_form",
          template:  "landlord_portal/tenants/extended_new")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def create_new
    @user = User.new
    @available_slots = AvailableSlotsBuilder.call(house: @house)
    @floors = @available_slots.floors
    @room_options = @available_slots.room_options
    @bed_options = @available_slots.bed_options
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
    redirect_to landlord_house_tenants_path(@house), alert: t("errors.rental_unit_unavailable")
  end

  # Remove a tenant from a house
  def destroy
    Checkout.call(
      house: @house,
      tenant_stay: @tenant_stay
    )

    @house.reload
    if @house.occupied_slots.zero?
      respond_to do |format|
        format.html { redirect_to landlord_house_tenants_path(@house), notice: t("success_messages.tenant_removed"), status: :see_other }
        format.turbo_stream { redirect_to landlord_house_tenants_path(@house), notice: t("success_messages.tenant_removed"), status: :see_other }
      end
      return
    end

    @stats = @house.tenant_summary_stats
    @unsigned_tenants = @house.all_linked_tenants(signed_contract: false)
    flash.now[:notice] = t("success_messages.tenant_removed")

    respond_to do |format|
      format.html { redirect_to landlord_house_tenants_path(@house), notice: t("success_messages.tenant_removed") }
      format.turbo_stream
    end
  rescue Checkout::PendingInvoicesError => e
    flash.now[:alert] = t("errors.tenant_has_pending_invoices", count: e.invoices.size)
    respond_to do |format|
      format.html { redirect_to landlord_house_tenants_path(@house), alert: flash.now[:alert] }
      format.turbo_stream { render :destroy_error, status: :unprocessable_entity }
    end
  end

  private

  def tenant_params
    params.expect(tenant_link_form: [ :tel ])
  end

  def authorize_tenant_belongs_to_house!
    @tenant_stay = @house.tenant_stay_for(params[:id])
    if @tenant_stay
      @tenant = @tenant_stay.tenant
    else
      @tenant = Tenant.find_by(id: params[:id])
      raise CanCan::AccessDenied unless @tenant && (@house.contracts.where(tenant: @tenant).exists? || @house.tenant_stay_for(@tenant.id).present?)
    end
  end

  def check_house_non_full
    return if @house.non_full?

    if turbo_frame_request? || request.format.turbo_stream?
      flash.now[:alert] = t("errors.house_full")
      render turbo_stream: turbo_stream.update(
        "flash",
        partial: "layouts/shared_components/flash_message"
      )
    else
      redirect_to landlord_house_tenants_path(@house), alert: t("errors.house_full")
    end
  end
end
