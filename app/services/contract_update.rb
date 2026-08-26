class ContractUpdate
  def self.call(...)
    new(...).call
  end

  def initialize(house:, contract:, params:, send_noti: true)
    @house = house
    @contract = contract
    @params = params
    @send_noti = send_noti
  end

  def call
    purge_ids = params[:purge_document_ids] || []
    new_docs = params[:documents]
    clean_params = params.except(:purge_document_ids, :documents, :start_date, :due_date, :end_date)

    Contract.transaction do
      # 1. Update general attributes
      contract.assign_attributes(clean_params)

      # 2. Reset temp_resid_due_date if temp residence is not registered
      if contract.temp_resid_registered == false || contract.temp_resid_registered == "false"
        contract.temp_resid_due_date = nil
      end

      # 3. Purge removed documents if specified
      if purge_ids.present?
        contract.documents.where(id: purge_ids).find_each(&:purge)
        contract.documents.reload
      end

      # 4. Attach new documents if specified
      if new_docs.present?
        contract.documents.attach(new_docs)
      end

      # 5. Save contract (which triggers ActiveRecord validations including validate_documents)
      contract.save!
    end

    send_notifications(contract) if @send_noti

    contract
  end

  private

  attr_reader :house, :contract, :params

  def send_notifications(contract)
    recipients = [ contract.tenant.user, contract.landlord.user ].compact.uniq

    ContractUpdatedNotifier.with(
      contract: contract,
      contract_id: contract.id,
      contract_name: contract.name,
      tenant_name: contract.tenant.user.fullname,
      house_id: house.id
    ).deliver_later(recipients)
  end
end
