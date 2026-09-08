class CreateIssueReports < ActiveRecord::Migration[8.0]
  def change
    create_table :issue_reports do |t|
      t.string :email, null: false
      t.string :title, null: false
      t.text :description, null: false
      t.string :status, default: "pending", null: false
      t.text :admin_notes
      t.datetime :resolved_at
      t.bigint :resolved_by_id

      t.timestamps
    end

    add_index :issue_reports, :status
    add_index :issue_reports, :created_at
    add_index :issue_reports, :email
    add_index :issue_reports, :resolved_by_id
    add_foreign_key :issue_reports, :admins, column: :resolved_by_id
  end
end
