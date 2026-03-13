class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  enum :role, { admin: 0, b2b_customer: 1 }

  has_many :quote_requests, dependent: :destroy
  has_many :created_quote_requests, class_name: "QuoteRequest", foreign_key: :created_by_user_id, dependent: :nullify, inverse_of: :created_by_user
  has_many :jobs, dependent: :nullify
  has_many :pricebook_imports, foreign_key: :imported_by_user_id, dependent: :restrict_with_error, inverse_of: :imported_by_user

  validates :role, presence: true
end
