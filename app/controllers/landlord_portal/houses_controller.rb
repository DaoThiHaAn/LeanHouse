  class LandlordPortal::HousesController < LandlordPortal::BaseController
    skip_before_action :set_house, only: [ :new, :create, :index ]
    skip_before_action :require_house, only: [ :new, :create ]
    before_action :set_location_data, only: [ :new, :edit ]

    # override Cancancan's behaviours
    # skip_load_and_authorize_resource only: [ :create ]
    authorize_resource # only: [ :create ]

    def index
      # Get all active houses sorted by name and matching query (if any)
      @houses = @landlord.houses.sorted.search(params[:query])
    end


    def show
      # Render a modal
      @floors = @house.floors.select(:id, :house_id, :name, :rooms_count)
      @services = @house.services.includes(:service_variants)
    end

    def new
      # Form model
      @form = HouseCreationForm.new
    end


    def edit
      @floors = @house.floors

      # For cancel button
      if turbo_frame_request?
        render partial: "general_info_form",
                locals: { house: @house, provinces: @provinces, communes: @communes }
      end
    end


    def create
      @form = HouseCreationForm.new(house_params.merge(landlord: @landlord))

      if @form.valid?
        @house = HouseCreation.new(
          landlord: @landlord,
          form: @form
        ).call

        redirect_to landlord_houses_path, notice: t("success_messages.house_created")
      else
        # Restore the values before submission
        data = JSON.parse(File.read(Rails.root.join("app/data/vn_locations.json")))
        @provinces = data["province"]
        @communes  = data["commune"]
        render :new, status: :unprocessable_entity
      end
    end


    def update
      respond_to do |format|
        if @house.update(house_params)
          format.html { redirect_to @house, notice: "House was successfully updated.", status: :see_other }
          format.json { render :show, status: :ok, location: @house }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @house.errors, status: :unprocessable_entity }
        end
      end
    end

    def change_mode
    end

    def check_delete
      @can_delete = @house.can_delete?
    end

    def destroy
      @house.destroy!

      respond_to do |format|
        format.html { redirect_to houses_path, notice: "House was successfully destroyed.", status: :see_other }
        format.json { head :no_content }
      end
    end

    def other_houses
      @other_houses = @landlord.get_other_houses(@house.id).select(:id, :name, :address_l1, :address_l2, :address_l3)
      render "house_list_modal"
    end


    private

    #  Override set_house in Base Controller
    def set_house
      @house = House.find(params.expect(:id))
    end

    def set_location_data
      # json data for locations
      data = JSON.parse(File.read(Rails.root.join("app/data/vn_locations.json")))
      @provinces = data["province"]
      @communes  = data["commune"]
    end

    # Only allow a list of trusted parameters through.
    def house_params
      params.require(:house).permit(
        :mode, :name,
        :address_l1, :address_l2, :address_l3,
        :has_ground_floor, :floors_count, :rooms_per_floor,
        :area, :rent, :capacity, :deposit,
        :inv_creation_date, :regulation_file,
        :elec_money, :elec_price, :elec_unit, :elec_real_time,
        :water_money, :water_price, :water_unit, :water_real_time,
        :wifi_money, :wifi_price, :wifi_unit,
        :parking_money, :parking_price, :parking_unit
      )
    end
  end
