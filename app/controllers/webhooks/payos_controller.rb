# frozen_string_literal: true

module Webhooks
  class PayosController < ActionController::API
    def receive
      result = Payos::ProcessWebhookService.call(params)
      render json: result[:json], status: result[:status]
    end
  end
end
