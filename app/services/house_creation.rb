class HouseCreation
  def initialize(landlord:, params:)
    @landlord = landlord # the current landlord creating the house
    @params = params
  end

  def call
    ActiveRecord::Base.transaction do
      house = @landlord.houses.new(house_attributes)

      assign_virtual_attributes(house)

      house.save!

      create_floors(house)
      create_rooms(house)
      create_beds(house)
      create_services(house)

      house
    end
  end

  private

  attr_reader :landlord, :params
end
