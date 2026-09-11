class LandlordPortal::BankAccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_landlord!
  before_action :set_landlord
  before_action :set_bank_account, only: %i[edit update destroy set_default]
  before_action :load_banks, only: %i[index create edit update]

  def index
    @bank_accounts = current_bank_accounts
    @bank_account = @landlord.bank_accounts.build
  end

  def create
    @bank_account = @landlord.bank_accounts.build(bank_account_create_params)

    if @bank_account.save
      @bank_accounts = current_bank_accounts
      @new_bank_account = @landlord.bank_accounts.build
      flash.now[:notice] = t("bank_account.created_success")

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to landlord_bank_accounts_path, notice: t("bank_account.created_success") }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "bank_account_form_container",
            partial: "landlord_portal/bank_accounts/form",
            locals: { bank_account: @bank_account, banks: @banks, bank_accounts_count: @landlord.bank_accounts.count }
          ), status: :unprocessable_entity
        end
        format.html do
          @bank_accounts = current_bank_accounts
          render :index, status: :unprocessable_entity
        end
      end
    end
  end

  def edit
    respond_to do |format|
      format.html
    end
  end

  def update
    if @bank_account.update(bank_account_update_params)
      @bank_accounts = current_bank_accounts
      flash.now[:notice] = t("bank_account.updated_success")

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to landlord_bank_accounts_path, notice: t("bank_account.updated_success") }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            view_context.dom_id(@bank_account),
            partial: "landlord_portal/bank_accounts/edit_form",
            locals: { bank_account: @bank_account, banks: @banks }
          ), status: :unprocessable_entity
        end
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def set_default
    @bank_account.update!(is_default: true)
    @bank_accounts = current_bank_accounts
    flash.now[:notice] = t("bank_account.set_default_success")

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to landlord_bank_accounts_path, notice: t("bank_account.set_default_success") }
    end
  end

  def destroy
    if @bank_account.has_unpaid_invoices?
      flash.now[:alert] = t("bank_account.cannot_delete_has_pending_invoices")
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("flash", partial: "layouts/shared_components/flash_message"), status: :unprocessable_entity
        end
        format.html do
          redirect_to landlord_bank_accounts_path, alert: t("bank_account.cannot_delete_has_pending_invoices")
        end
      end
      return
    end

    @bank_account.destroy
    @bank_accounts = current_bank_accounts
    @new_bank_account = @landlord.bank_accounts.build
    load_banks
    flash.now[:notice] = t("bank_account.deleted_success")

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to landlord_bank_accounts_path, notice: t("bank_account.deleted_success") }
    end
  end

  private

  def require_landlord!
    raise CanCan::AccessDenied unless current_user&.landlord?
  end

  def set_landlord
    @landlord = current_user.landlord
  end

  def set_bank_account
    @bank_account = @landlord.bank_accounts.find(params[:id])
  end

  def load_banks
    @banks = Bank.sorted
  end

  def current_bank_accounts
    @landlord.bank_accounts.reload.includes(:bank).default_first
  end

  def bank_account_create_params
    params.require(:bank_account).permit(
      :bank_id, :account_number, :account_holder, :is_default, :consent_accepted,
      :payos_enabled, :payos_client_id, :payos_api_key, :payos_checksum_key
    )
  end

  def bank_account_update_params
    params.require(:bank_account).permit(
      :account_number, :account_holder, :is_default,
      :payos_enabled, :payos_client_id, :payos_api_key, :payos_checksum_key
    )
  end
end
