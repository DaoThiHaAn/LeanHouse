class AddNoteToContract < ActiveRecord::Migration[8.0]
  def change
    add_column :contracts, :note, :string
  end
end
