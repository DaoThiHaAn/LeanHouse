class AddTransferNoteTemplateToHouses < ActiveRecord::Migration[8.0]
  def change
    add_column :houses, :transfer_note_template, :string
  end
end
