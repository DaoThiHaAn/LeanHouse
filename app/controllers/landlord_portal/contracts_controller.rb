class LandlordPortal::ContractsController < LandlordPortal::BaseController
  layout "house_mngment"

  load_and_authorize_resource :contract, through: :house, except: %i[new create index filtered]
  before_action :authorize_tenant_belongs_to_house!, only: [ :new, :create ]

  def new
    @contract = Contract.new
  end

  def create
    @contract = ContractSigning.call(
      house: @house,
      tenant_stay: @tenant_stay,
      landlord: @landlord,
      params: contract_params
    )
    redirect_to landlord_house_contracts_path(@house),
                notice: t("success_messages.contract_created")

  rescue ActiveRecord::RecordInvalid => e
    @contract = e.record.is_a?(Contract) ? e.record : @house.contracts.build(contract_params)
    render :new, status: :unprocessable_entity
  end

  def show
  end

  def index
    @unsigned_tenants = @house.all_linked_tenants(signed_contract: false)
    # Extract all contracts of only current staying tenants
    @has_contracts = @house.all_current_contracts.expiring_soonest
  end

  def filtered
    @contracts = ContractFilter.call(house: @house, params: params)
    render partial: "contract_table",
           locals: { house: @house, contracts: @contracts }
  end

  def close
  end

  def destroy
  end

  private

  def authorize_tenant_belongs_to_house!
    @tenant_stay = @house.tenant_stay_for(params[:tenant_id])
    raise CanCan::AccessDenied unless @tenant_stay
    @user = @tenant_stay.tenant.user
  end

  def contract_params
    params.require(:contract).permit(
      :name, :citizen_id, :start_date, :due_date, :note, :deposit_paid,
      :deposit_paid, :temp_resid_registered, :temp_resid_due_date,
      documents: [] # Cho phép nhận mảng file ảnh upload
    )
  end
end
