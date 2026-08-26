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
    @tenant_stay = @house.tenant_stay_for(@contract.tenant_id)
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

  def edit
    @tenant_stay = @house.tenant_stay_for(@contract.tenant_id)
    @user = @contract.tenant.user
  end

  def update
    @tenant_stay = @house.tenant_stay_for(@contract.tenant_id)
    @user = @contract.tenant.user

    ContractUpdate.call(
      house: @house,
      contract: @contract,
      params: update_contract_params
    )

    redirect_to landlord_house_contract_path(@house, @contract),
                notice: t("success_messages.contract_updated", default: "Cập nhật hợp đồng thành công!")
  rescue ActiveRecord::RecordInvalid => e
    render :edit, status: :unprocessable_entity
  end

  def extend
  end

  def execute_extend
    ContractExtension.call(
      house: @house,
      contract: @contract,
      params: extend_contract_params
    )

    respond_to do |format|
      format.turbo_stream do
        @tenant_stay = @house.tenant_stay_for(@contract.tenant_id)
        flash.now[:notice] = t("success_messages.contract_extended", default: "Gia hạn hợp đồng thành công!")
        render turbo_stream: [
          turbo_stream.replace(
            ActionView::RecordIdentifier.dom_id(@contract),
            partial: "landlord_portal/contracts/contract_row",
            locals: { house: @house, contract: @contract }
          ),
          turbo_stream.replace(
            "contract_detail",
            partial: "landlord_portal/contracts/detail",
            locals: { house: @house, contract: @contract, tenant_stay: @tenant_stay }
          ),
          turbo_stream.append(
            "events",
            partial: "layouts/shared_components/event",
            locals: { event: "close-modal" }
          ),
          turbo_stream.update("flash", partial: "layouts/shared_components/flash_message")
        ]
      end
      format.html do
        redirect_to landlord_house_contracts_path(@house),
                    notice: t("success_messages.contract_extended", default: "Gia hạn hợp đồng thành công!")
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = @contract.errors.full_messages.to_sentence.presence || t("errors.unprocessable_entity")
    render turbo_stream: turbo_stream.replace(
      "extend_modal",
      template: "landlord_portal/contracts/extend"
    ), status: :unprocessable_entity
  end


  def sign_new
    @old_contract = @contract
    @tenant_stay = @house.tenant_stay_for(@old_contract.tenant_id)
    raise CanCan::AccessDenied unless @tenant_stay

    @user = @tenant_stay.tenant.user
    @contract = Contract.new(
      name: @old_contract.name,
      landlord_citizen_id: @old_contract.landlord_citizen_id,
      tenant_citizen_id: @old_contract.tenant_citizen_id,
      deposit_paid: @old_contract.deposit_paid,
      temp_resid_registered: @old_contract.temp_resid_registered,
      temp_resid_due_date: @old_contract.temp_resid_due_date
    )
  end

  def execute_sign_new
    @old_contract = @contract
    @tenant_stay = @house.tenant_stay_for(@old_contract.tenant_id)
    raise CanCan::AccessDenied unless @tenant_stay

    @user = @tenant_stay.tenant.user

    @contract = ContractRenewal.call(
      house: @house,
      old_contract: @old_contract,
      tenant_stay: @tenant_stay,
      landlord: @landlord,
      params: contract_params
    )

    redirect_to landlord_house_contract_path(@house, @contract),
                notice: t("success_messages.contract_signed_new", default: "Ký hợp đồng mới thành công!")
  rescue ActiveRecord::RecordInvalid => e
    @contract = e.record.is_a?(Contract) ? e.record : @house.contracts.build(contract_params)
    render :sign_new, status: :unprocessable_entity
  end

  def close
    @tenant_stay = @house.tenant_stay_for(@contract.tenant_id)
  end

  def destroy
    remove_tenant = params[:remove_tenant] == "1"

    ContractClosing.call(
      house: @house,
      contract: @contract,
      remove_tenant: remove_tenant
    )

    redirect_to landlord_house_contracts_path(@house),
                notice: t("success_messages.contract_closed", default: "Kết thúc hợp đồng thành công!")
  end

  private

  def authorize_tenant_belongs_to_house!
    @tenant_stay = @house.tenant_stay_for(params[:tenant_id])
    raise CanCan::AccessDenied unless @tenant_stay
    @user = @tenant_stay.tenant.user
  end

  def contract_params
    params.require(:contract).permit(
      :name, :tenant_citizen_id, :landlord_citizen_id, :start_date, :due_date, :note, :deposit_paid,
      :temp_resid_registered, :temp_resid_due_date,
      documents: [] # Cho phép nhận mảng file ảnh upload
    )
  end

  def extend_contract_params
    params.require(:contract).permit(:due_date)
  end

  def update_contract_params
    params.require(:contract).permit(
      :name, :tenant_citizen_id, :landlord_citizen_id, :note, :deposit_paid,
      :temp_resid_registered, :temp_resid_due_date,
      documents: [],
      purge_document_ids: []
    )
  end
end
