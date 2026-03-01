# frozen_string_literal: true

RSpec.describe "Redirect after activation" do
  fab!(:user) { Fabricate(:user, active: false) }

  let(:email_token) do
    user.email_tokens.create!(email: user.email, scope: EmailToken.scopes[:signup])
  end

  before do
    SiteSetting.redirect_after_activation_enabled = true
    SiteSetting.redirect_after_activation_url = "https://example.com/welcome"
  end

  describe "email confirmation flow" do
    it "injects redirect_to in the activation response" do
      put "/u/activate-account/#{email_token.token}.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["redirect_to"]).to eq("https://example.com/welcome")
    end

    context "when redirect URL is blank" do
      before { SiteSetting.redirect_after_activation_url = "" }

      it "does not set a redirect URL" do
        put "/u/activate-account/#{email_token.token}.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["redirect_to"]).to be_nil
      end
    end

    context "when plugin is disabled" do
      before { SiteSetting.redirect_after_activation_enabled = false }

      it "does not set a redirect URL" do
        put "/u/activate-account/#{email_token.token}.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["redirect_to"]).to be_nil
      end
    end

    context "when a destination_url cookie already provides a redirect" do
      it "preserves the existing redirect" do
        cookies[:destination_url] = "/t/some-topic/123"
        put "/u/activate-account/#{email_token.token}.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["redirect_to"]).to eq("/t/some-topic/123")
      end
    end
  end

  describe "OAuth auto-activation flow" do
    let(:oauth_user) { Fabricate(:user, active: true, created_at: 5.seconds.ago) }

    context "when a new user signs up via OAuth" do
      it "sets the redirect location to the configured URL" do
        auth_result = Auth::Result.new
        auth_result.user = oauth_user
        auth_result.authenticated = true

        controller = Users::OmniauthCallbacksController.new
        allow(controller).to receive(:response).and_return(ActionDispatch::Response.new)
        controller.instance_variable_set(:@auth_result, auth_result)
        controller.send(:inject_oauth_redirect_after_activation)

        expect(controller.response.location).to eq("https://example.com/welcome")
      end
    end

    context "when an existing user logs in via OAuth" do
      it "does not change the redirect location" do
        old_user = Fabricate(:user, active: true, created_at: 1.year.ago)

        auth_result = Auth::Result.new
        auth_result.user = old_user
        auth_result.authenticated = true

        controller = Users::OmniauthCallbacksController.new
        allow(controller).to receive(:response).and_return(ActionDispatch::Response.new)
        controller.instance_variable_set(:@auth_result, auth_result)
        controller.send(:inject_oauth_redirect_after_activation)

        expect(controller.response.location).to be_nil
      end
    end
  end

  describe "helper methods" do
    it "reports enabled when setting and URL are present" do
      expect(RedirectAfterActivation.enabled?).to eq(true)
    end

    it "reports disabled when URL is blank" do
      SiteSetting.redirect_after_activation_url = ""
      expect(RedirectAfterActivation.enabled?).to eq(false)
    end

    it "reports disabled when setting is off" do
      SiteSetting.redirect_after_activation_enabled = false
      expect(RedirectAfterActivation.enabled?).to eq(false)
    end
  end
end
