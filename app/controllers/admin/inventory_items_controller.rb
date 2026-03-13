class Admin::InventoryItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_inventory_item, only: %i[edit update adjust_stock destroy]

  def index
    @inventory_items = InventoryItem.order(:component_type, :name)
  end

  def new
    @inventory_item = InventoryItem.new(active: true, on_hand: 0)
  end

  def create
    @inventory_item = InventoryItem.new(inventory_item_params)
    if @inventory_item.save
      redirect_to admin_inventory_items_path, notice: "Inventory item created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @inventory_item.update(inventory_item_params)
      redirect_to admin_inventory_items_path, notice: "Inventory item updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @inventory_item.destroy
      redirect_to admin_inventory_items_path, notice: "Inventory item deleted."
    else
      redirect_to admin_inventory_items_path, alert: @inventory_item.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::InvalidForeignKey
    redirect_to admin_inventory_items_path, alert: "Inventory item is linked to a product and cannot be deleted."
  end

  def adjust_stock
    mode = params[:mode].to_s
    amount = params[:amount].to_i
    previous_on_hand = @inventory_item.on_hand

    if amount.negative?
      redirect_to admin_inventory_items_path, alert: "Amount must be zero or greater."
      return
    end

    @inventory_item.with_lock do
      previous_on_hand = @inventory_item.on_hand
      case mode
      when "set"
        @inventory_item.on_hand = amount
      when "increase"
        @inventory_item.on_hand += amount
      when "decrease"
        @inventory_item.on_hand = [ @inventory_item.on_hand - amount, 0 ].max
      else
        redirect_to admin_inventory_items_path, alert: "Unknown stock action."
        return
      end

      @inventory_item.save!
    end

    redirect_to admin_inventory_items_path, notice: "#{@inventory_item.name} stock updated from #{previous_on_hand} to #{@inventory_item.on_hand}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_inventory_items_path, alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_inventory_item
    @inventory_item = InventoryItem.find(params[:id])
  end

  def inventory_item_params
    params.require(:inventory_item).permit(:name, :sku, :component_type, :on_hand, :active, :notes)
  end
end
