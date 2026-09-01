class TenantPortal::InvoicesController < TenantPortal::BaseController
  before_action :set_room

  def index
    @invoices = @house.invoices
                      .where("invoices.room_id = :room_id OR invoices.tenant_id = :tenant_id", room_id: @room.id, tenant_id: @tenant.id)
                      .kept
                      .includes(:room, :tenant, :bank_account)
                      .sorted
  end

  def show
    @invoice = @house.invoices
                     .where("invoices.room_id = :room_id OR invoices.tenant_id = :tenant_id", room_id: @room.id, tenant_id: @tenant.id)
                     .find(params[:id])
    @items = @invoice.invoice_items.order(created_at: :asc)
    @bank_account = @invoice.bank_account
  end

  private

  def set_room
    @room = @tenant_stay.rental_unit.room
  end
end
