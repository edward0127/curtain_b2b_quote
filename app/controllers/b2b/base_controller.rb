class B2b::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_b2b_customer!
end
