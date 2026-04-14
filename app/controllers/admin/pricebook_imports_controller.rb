class Admin::PricebookImportsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def index
    @pricebook_imports = PricebookImport.includes(:imported_by_user).recent_first.limit(20)
  end

  def new
    @pricebook_import = PricebookImport.new
  end

  def create
    uploaded_file = params.dig(:pricebook_import, :file)
    unless uploaded_file.present?
      redirect_to new_admin_pricebook_import_path, alert: "Please select an .xlsx file to import."
      return
    end

    import = PricebookImport.create!(
      imported_by_user: current_user,
      import_type: Pricebook::CurtainPricingImporter::IMPORT_TYPE,
      source_filename: uploaded_file.original_filename.to_s
    )
    import.start!

    file_path = if uploaded_file.respond_to?(:tempfile) && uploaded_file.tempfile.present?
      uploaded_file.tempfile.path
    elsif uploaded_file.respond_to?(:path)
      uploaded_file.path
    end

    raise ArgumentError, "Uploaded file could not be read." if file_path.blank?

    result = Pricebook::CurtainPricingImporter.new(
      file_path: file_path,
      source_filename: uploaded_file.original_filename.to_s,
      imported_by: current_user
    ).import!

    import.succeed!(
      products_updated_count: result.products_updated_count,
      price_matrix_entries_count: result.price_matrix_entries_count,
      track_price_tiers_count: result.track_price_tiers_count,
      log_output: result.log_output
    )

    redirect_to admin_pricebook_imports_path, notice: "Pricebook imported successfully using the active Curtain Pricing workbook format."
  rescue StandardError => e
    import&.fail!(error_message: e.message, log_output: e.full_message)
    redirect_to admin_pricebook_imports_path, alert: "Pricebook import failed: #{e.message}"
  end
end
