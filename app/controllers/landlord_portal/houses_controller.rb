  class LandlordPortal::HousesController < LandlordPortal::BaseController
    skip_before_action :set_house, only: [ :new, :create, :index ]
    skip_before_action :require_house, only: [ :new, :create ]
    before_action :set_location_data, only: [ :new, :edit ]

    # override Cancancan's behaviours
    # skip_load_and_authorize_resource only: [ :create ]
    authorize_resource # only: [ :create ]

    def index
      # Get all active houses sorted by name, matching query, state, and invoice_status filter
      @houses = @landlord.houses
                         .active
                         .sorted
                         .search(params[:query])
                         .by_state(params[:state])
                         .by_invoice_status(params[:invoice_status])

      @unpaid_invoices_counts = Invoice.kept
                                       .where(house_id: @houses.select(:id), status: %w[pending overdue])
                                       .group(:house_id)
                                       .count
    end


    def show
      # Render a modal
      @floors = @house.floors.select(:id, :house_id, :name, :rooms_count)
      @services = @house.services.includes(:service_variants)
      @asset_stats = @house.asset_summary_stats
    end

    def new
      # Form model
      @form = HouseCreationForm.new
    end


    def edit
      @floors = @house.floors.pos_order

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
          format.html { redirect_to [ :landlord, @house ], notice: "House was successfully updated.", status: :see_other }
          format.json { render :show, status: :ok, location: [ :landlord, @house ] }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @house.errors, status: :unprocessable_entity }
        end
      end
    end

    def change_mode
      if HouseModeChanger.new(@house).call
        redirect_to edit_landlord_house_path(@house), notice: t("success_messages.house_mode_changed")
      else
        redirect_to edit_landlord_house_path(@house), alert: t("form.house.change_mode_blocked")
      end
    end

    def check_deletion
      if @house.can_delete?
        render :check_deletion_confirm
      else
        render :check_deletion_blocked
      end
    end

    def destroy
      if @house.can_delete?
        @house.soft_delete!
        redirect_to landlord_houses_path, notice: t("success_messages.house_deleted")
      else
        redirect_to edit_landlord_house_path(@house), alert: t("errors.house_cant_deleted")
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
