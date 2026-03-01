# frozen_string_literal: true

# name: discourse-redirect-after-activation
# about: Redirects users to a configurable URL after account activation (email confirmation or admin approval)
# meta_topic_id: TODO
# version: 1.0.0
# authors: linharesplay
# url: https://github.com/linharesplay/discourse-redirect-after-activation
# required_version: 2.7.0

enabled_site_setting :redirect_after_activation_enabled

module ::RedirectAfterActivation
  PLUGIN_NAME = "discourse-redirect-after-activation"
end

require_relative "lib/redirect_after_activation/engine"

after_initialize do
  add_to_class(:users_controller, :inject_redirect_after_activation) do
    return unless SiteSetting.redirect_after_activation_enabled
    return if SiteSetting.redirect_after_activation_url.blank?
    return unless response.successful?
    return unless @user&.active?
    return if @needs_approval

    begin
      json_body = JSON.parse(response.body)
    rescue JSON::ParserError
      return
    end

    return unless json_body.is_a?(Hash)
    return if json_body["redirect_to"].present?

    json_body["redirect_to"] = SiteSetting.redirect_after_activation_url
    response.body = json_body.to_json
  end

  ::UsersController.after_action :inject_redirect_after_activation,
                                 only: [:perform_account_activation]
end
