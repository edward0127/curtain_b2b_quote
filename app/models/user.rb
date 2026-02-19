class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  enum :role, { admin: 0, b2b_customer: 1 }

  has_many :quote_requests, dependent: :destroy

  validates :role, presence: true
end
