# frozen_string_literal: true

# name: discourse-redirect-after-activation
# about: Redirects new users to a configurable URL after account activation via any signup method (email, OAuth, admin approval)
# meta_topic_id: TODO
# version: 1.1.0
# authors: linharesplay
# url: https://github.com/linharesplay/discourse-redirect-after-activation
# required_version: 2.7.0

enabled_site_setting :redirect_after_activation_enabled

module ::RedirectAfterActivation
  PLUGIN_NAME = "discourse-redirect-after-activation"

  def self.redirect_url
    SiteSetting.redirect_after_activation_url.presence
  end

  def self.enabled?
    SiteSetting.redirect_after_activation_enabled && redirect_url.present?
  end
end

require_relative "lib/redirect_after_activation/engine"

after_initialize do
  # ── Flow 1: Email confirmation ─────────────────────────────
  # perform_account_activation returns JSON with redirect_to.
  # We inject our URL when no other redirect is set.

  add_to_class(:users_controller, :inject_redirect_after_activation) do
    return unless RedirectAfterActivation.enabled?
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

    json_body["redirect_to"] = RedirectAfterActivation.redirect_url
    response.body = json_body.to_json
  end

  ::UsersController.after_action :inject_redirect_after_activation,
                                 only: [:perform_account_activation]

  # ── Flow 2: OAuth (Google, Discord, GitHub, Steam, etc.) ───
  # OmniauthCallbacksController#complete ends with redirect_to @origin.
  # For brand-new users who are auto-activated via OAuth, we override
  # the redirect location to point to our configured URL.

  add_to_class(Users::OmniauthCallbacksController, :inject_oauth_redirect_after_activation) do
    return unless RedirectAfterActivation.enabled?
    return unless @auth_result&.authenticated
    return unless @auth_result&.user.present?

    user = @auth_result.user

    # Only redirect brand-new users, not returning logins.
    # A user created within the last 60 seconds is considered new.
    return unless user.created_at > 60.seconds.ago

    redirect_url = RedirectAfterActivation.redirect_url

    # Override the redirect location set by the complete action.
    # For internal paths, use as-is. For absolute URLs, set directly.
    if redirect_url.start_with?("http://", "https://")
      response.location = redirect_url
    else
      response.location = "#{Discourse.base_path}#{redirect_url}"
    end
  end

  Users::OmniauthCallbacksController.after_action :inject_oauth_redirect_after_activation,
                                                   only: [:complete]

  # ── Flow 3: OAuth signup requiring form completion ─────────
  # When OAuth doesn't provide enough data, the user fills a form
  # and UsersController#create is called. The JSON response includes
  # a redirect_to if present. We inject our URL for new users.

  add_to_class(:users_controller, :inject_create_redirect_after_activation) do
    return unless RedirectAfterActivation.enabled?
    return unless response.successful?

    begin
      json_body = JSON.parse(response.body)
    rescue JSON::ParserError
      return
    end

    return unless json_body.is_a?(Hash)
    return unless json_body["success"]

    # Only inject if user is active (auto-activated via OAuth email verification)
    # and no other redirect is already set.
    user_id = json_body["user_id"]
    return if user_id.blank?

    user = User.find_by(id: user_id)
    return unless user&.active?
    return if json_body["redirect_to"].present?

    json_body["redirect_to"] = RedirectAfterActivation.redirect_url
    response.body = json_body.to_json
  end

  ::UsersController.after_action :inject_create_redirect_after_activation,
                                 only: [:create]
end
