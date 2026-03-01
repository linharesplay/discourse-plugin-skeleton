# frozen_string_literal: true

RedirectAfterActivation::Engine.routes.draw do
  # No custom routes needed - this plugin hooks into core's activation flow
end

Discourse::Application.routes.draw do
  mount ::RedirectAfterActivation::Engine, at: "redirect-after-activation"
end
