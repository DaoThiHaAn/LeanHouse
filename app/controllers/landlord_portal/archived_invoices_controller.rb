module LandlordPortal
  class ArchivedInvoicesController < BaseController
    skip_before_action :require_house, :set_house, :authorize_house

    def index
      if @landlord.deleted_houses_count.zero?
        @houses = House.none
        @invoices = Invoice.none
        return
      end

      @query = params[:q].presence || params[:query].presence
      @house_id = params[:house_id].presence
      @month = params[:month].presence

      @houses = @landlord.houses.deleted.sorted
      @invoices = LandlordInvoiceArchiveFilter.call(landlord: @landlord, params: params)
    end

    def show
      @invoice = Invoice.joins(:house)
                        .where(houses: { landlord_id: @landlord.id, is_deleted: true })
                        .includes(:house, :room, :bank_account, tenant: :user)
                        .find(params[:id])
      authorize! :manage, @invoice

      @house = @invoice.house
      @items = @invoice.invoice_items.order(created_at: :asc)
      @bank_account = @invoice.bank_account || @landlord.bank_accounts.default_first.first
    end
  end
end
