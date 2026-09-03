module AdminPortal
  class ContractsController < BaseController
    before_action :set_house, only: [ :index ]
    before_action :set_contract, only: [ :show ]

    def index
      @query = params[:q].presence || params[:query].presence
      @state = params[:state].presence

      @contracts = ContractFilter.call(house: @house, params: { q: @query, state: @state, page: params[:page] })
      @total_contracts_count = @house.contracts.count
      @active_contracts_count = @house.contracts.unfinished.where("due_date >= ?", Date.current).count
      @nearly_due_count = @house.contracts.unfinished.nearly_due.count
      @overdue_count = @house.contracts.unfinished.overdue.count
      @finished_count = @house.contracts.finished.count
    end

    def show
      @house = @contract.house
      @tenant_stay = @house.tenant_stay_for(@contract.tenant_id)
    end

    private

    def set_house
      @house = House.active.includes(landlord: :user).find(params[:house_id])
    end

    def set_contract
      @contract = Contract.includes(:house, :landlord, tenant: :user).find(params[:id])
    end
  end
end
