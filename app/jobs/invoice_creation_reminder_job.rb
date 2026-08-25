class InvoiceCreationReminderJob < ApplicationJob
  queue_as :default

  def perform
    today = Date.current
    is_last_day_of_month = (today == today.end_of_month)

    houses = if is_last_day_of_month
      House.active.where("inv_creation_date >= ?", today.day)
    else
      House.active.where(inv_creation_date: today.day)
    end

    houses.includes(landlord: :user).find_each do |house|
      InvoiceCreationReminderNotifier.with(
        house: house,
        house_id: house.id,
        house_name: house.name
      ).deliver_later(house.landlord.user)
    end
  end
end
