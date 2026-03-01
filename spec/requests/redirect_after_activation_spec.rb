# frozen_string_literal: true

RSpec.describe "Redirect after activation" do
  fab!(:user) { Fabricate(:user, active: false) }

  let(:email_token) do
    user.email_tokens.create!(email: user.email, scope: EmailToken.scopes[:signup])
  end

  before { SiteSetting.redirect_after_activation_enabled = true }

  context "when redirect URL is configured" do
    before { SiteSetting.redirect_after_activation_url = "https://example.com/welcome" }

    it "redirects to the configured URL after account activation" do
      put "/u/activate-account/#{email_token.token}.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["redirect_to"]).to eq("https://example.com/welcome")
    end
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
    before do
      SiteSetting.redirect_after_activation_enabled = false
      SiteSetting.redirect_after_activation_url = "https://example.com/welcome"
    end

    it "does not set a redirect URL" do
      put "/u/activate-account/#{email_token.token}.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["redirect_to"]).to be_nil
    end
  end

  context "when a destination_url cookie is already set" do
    before { SiteSetting.redirect_after_activation_url = "https://example.com/welcome" }

    it "preserves the existing redirect from destination_url cookie" do
      cookies[:destination_url] = "/t/some-topic/123"
      put "/u/activate-account/#{email_token.token}.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["redirect_to"]).to eq("/t/some-topic/123")
    end
  end
end
