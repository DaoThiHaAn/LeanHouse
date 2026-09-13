module LandlordPortal
  class ArchivedContractsController < BaseController
    skip_before_action :require_house, :set_house, :authorize_house

    def index
      if @landlord.deleted_houses_count.zero?
        @houses = House.none
        @contracts = Contract.none
        return
      end

      @query = params[:q].presence || params[:query].presence
      @house_id = params[:house_id].presence

      @houses = @landlord.houses.deleted.sorted
      @contracts = LandlordContractArchiveFilter.call(landlord: @landlord, params: params)
    end

    def show
      @contract = @landlord.contracts.joins(:house).where(houses: { is_deleted: true }).includes(:house, :landlord, tenant: :user).find(params[:id])
      authorize! :manage, @contract

      @house = @contract.house
      @tenant_stay = @house.tenant_stay_for(@contract.tenant_id) || @house.historical_tenant_stay_for(@contract.tenant_id)
    end
  end
end
