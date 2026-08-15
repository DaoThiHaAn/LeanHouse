class LandlordPortal::BedsController < LandlordPortal::BaseController
  layout "house_mngment"

  def index
    @beds = filtered_beds
  end

  def new
  end

  def create
  end

  def edit
  end

  def update
  end

  def delete
  end

  def filtered_table
    @beds = filtered_beds

    render partial: "bed_table", locals: { house: @house, beds: @beds }
  end


  private
  def filtered_beds
    scope = @house.beds.active
                  .joins(room: :floor)
                  .includes(
                    room: :floor,
                    staying_tenant: :user
                  )

    case params[:state]
    when "available"
      scope = scope.available
    when "full"
      scope = scope.empty
    end

    scope.order("floors.name ASC, rooms.name ASC, beds.name ASC")
         .page(params[:page])
         .per(20)
  end
end
