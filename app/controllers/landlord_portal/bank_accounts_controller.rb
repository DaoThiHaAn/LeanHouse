class LandlordPortal::BankAccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_landlord!
  before_action :set_landlord
  before_action :set_bank_account, only: %i[destroy set_default]

  def index
    @bank_accounts = @landlord.bank_accounts.includes(:bank).default_first
    @bank_account = @landlord.bank_accounts.build
    @banks = Bank.sorted
  end

  def create
    @bank_account = @landlord.bank_accounts.build(bank_account_params)

    if @bank_account.save
      redirect_to landlord_bank_accounts_path, notice: t("bank_account.created_success")
    else
      @bank_accounts = @landlord.bank_accounts.includes(:bank).default_first
      @banks = Bank.sorted
      render :index, status: :unprocessable_entity
    end
  end

  def set_default
    @bank_account.update!(is_default: true)
    redirect_to landlord_bank_accounts_path, notice: t("bank_account.set_default_success")
  end

  def destroy
    @bank_account.destroy
    redirect_to landlord_bank_accounts_path, notice: t("bank_account.deleted_success")
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

  def bank_account_params
    params.require(:bank_account).permit(:bank_id, :account_number, :account_holder, :is_default)
  end
end
