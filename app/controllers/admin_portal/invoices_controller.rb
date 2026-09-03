module AdminPortal
  class InvoicesController < BaseController
    before_action :set_house, only: [ :index ]
    before_action :set_invoice, only: [ :show ]

    def index
      @query = params[:q].presence || params[:query].presence
      @state = params[:state].presence

      @invoices = InvoiceFilter.call(house: @house, params: { q: @query, state: @state, page: params[:page] })
      @total_invoices_count = @house.invoices.count
      @paid_invoices_count = @house.invoices.paid.count
      @pending_invoices_count = @house.invoices.pending.count
      @overdue_invoices_count = @house.invoices.overdue.count
    end

    def show
      @house = @invoice.house
      @invoice_items = @invoice.invoice_items.order(id: :asc)
      @rent_item = @invoice_items.find(&:rent?)
      @service_items = @invoice_items.select(&:service?)
      @addition_items = @invoice_items.select(&:addition?)
      @discount_items = @invoice_items.select(&:discount?)
      @bank_account = @invoice.bank_account
    end

    private

    def set_house
      @house = House.active.includes(landlord: :user).find(params[:house_id])
    end

    def set_invoice
      @invoice = Invoice.includes(:house, :room, :paid_by, :undone_by, tenant: :user, bank_account: :bank).find(params[:id])
    end
  end
end
