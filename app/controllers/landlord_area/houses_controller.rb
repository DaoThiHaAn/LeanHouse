  class LandlordArea::HousesController < LandlordArea::BaseController
    before_action :set_house, only: %i[ show edit update destroy ]
    skip_before_action :require_house, only: :new

    def index
      @houses = House.all
    end

    def show
    end

    def new
      @house = House.new
      data = JSON.parse(File.read(Rails.root.join("app/data/vn_locations.json")))
      @provinces = data["province"]
      @communes  = data["commune"]
    end

    def edit
    end

    def create
      @house = House.new(house_params)

      respond_to do |format|
        if @house.save
          format.html { redirect_to @house, notice: "House was successfully created." }
          format.json { render :show, status: :created, location: @house }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @house.errors, status: :unprocessable_entity }
        end
      end
    end

    # PATCH/PUT /houses/1 or /houses/1.json
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

    # DELETE /houses/1 or /houses/1.json
    def destroy
      @house.destroy!

      respond_to do |format|
        format.html { redirect_to houses_path, notice: "House was successfully destroyed.", status: :see_other }
        format.json { head :no_content }
      end
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_house
        @house = House.find(params.expect(:id))
      end

      # Only allow a list of trusted parameters through.
      def house_params
        params.require(:house).permit(
          :name,
          :mode,
          :address_l1,
          :address_l2,
          :address_l3,
          :floors_count,
          :rooms_per_floor,
          :inv_creation_date,
          :regulation_file
        )
      end
  end
