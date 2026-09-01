class LandlordPortal::ServicesController < LandlordPortal::BaseController
  layout "house_mngment"

  before_action :set_service, only: %i[show edit update destroy]
  before_action :set_services_and_totals, only: %i[index show]

  def index
    if params[:service_id].present?
      @selected_service = @services.find { |s| s.id == params[:service_id].to_i }
    end
  end

  def show
    @selected_service = @service

    respond_to do |format|
      format.html do
        if turbo_frame_request?
          render :show
        else
          render :index
        end
      end
    end
  end

  def new
    @service = @house.services.build
  end

  def create
    @service = @house.services.build(service_params)

    if @service.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to landlord_house_service_path(@house, @service), notice: t("success_messages.service_created", default: "Tạo dịch vụ thành công!") }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @service.update(service_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to landlord_house_service_path(@house, @service), notice: t("success_messages.service_updated", default: "Cập nhật dịch vụ thành công!") }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @service.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to landlord_house_services_path(@house), notice: t("success_messages.service_deleted", default: "Đã xóa dịch vụ!") }
    end
  end

  private

  def set_service
    @service = @house.services.includes(service_variants: :rooms).find(params[:id])
  end

  def set_services_and_totals
    @services = @house.services.name_sorted.includes(service_variants: :rooms)
    @total_house_rooms = @house.rooms.active.count
  end

  def service_params
    params.require(:service).permit(:name, :note)
  end
end
