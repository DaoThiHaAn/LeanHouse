class LandlordPortal::ServiceVariantsController < LandlordPortal::BaseController
  layout "house_mngment"

  before_action :set_service
  before_action :set_variant, only: %i[edit update edit_application update_application destroy]
  before_action :set_total_rooms, only: %i[create update update_application]

  def new
    @service_variant = @service.service_variants.build(unit: :per_month)
  end

  def create
    @service_variant = @service.service_variants.build(variant_params)

    if @service_variant.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to landlord_house_service_path(@house, @service), notice: t("success_messages.variant_created", default: "Thêm phiên bản dịch vụ thành công!") }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if ServiceVariantUpdater.update_meta(@service_variant, variant_params, notify: params[:notify_tenants] == "1")
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to landlord_house_service_path(@house, @service), notice: t("success_messages.variant_updated", default: "Cập nhật phiên bản dịch vụ thành công!") }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def edit_application
    @eligible_rooms = @service_variant.eligible_rooms
    @assigned_room_ids = @service_variant.room_services.pluck(:room_id).to_set
  end

  def update_application
    ServiceVariantUpdater.update_application(@service_variant, params[:room_ids], notify: params[:notify_tenants] == "1")
    @service_variant.reload

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to landlord_house_service_path(@house, @service), notice: t("success_messages.application_updated", default: "Cập nhật phòng áp dụng thành công!") }
    end
  end

  def destroy
    @service_variant.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to landlord_house_service_path(@house, @service), notice: t("success_messages.variant_deleted", default: "Đã xóa phiên bản dịch vụ!") }
    end
  end

  private

  def set_service
    @service = @house.services.find(params[:service_id])
  end

  def set_variant
    @service_variant = @service.service_variants.includes(:rooms).find(params[:id])
  end

  def set_total_rooms
    @total_house_rooms = @house.rooms.active.count
  end

  def variant_params
    params.require(:service_variant).permit(:fee, :unit, :is_real_time)
  end
end
