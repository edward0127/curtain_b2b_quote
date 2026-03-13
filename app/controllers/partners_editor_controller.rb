require "tempfile"
require "uri"

class PartnersEditorController < ApplicationController
  MAX_IMAGE_BYTES = 1.megabyte
  LOCAL_IMAGE_UPLOAD_PREFIX = "/uploads/public_pages/"
  S3_OBJECT_PREFIX = "public_pages/"

  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_page_key
  before_action :load_page_editor_content, only: [ :home, :partners, :builders ]

  def home
    render :home
  end

  def partners
    render :partners
  end

  def builders
    render :builders
  end

  def update
    action = params[:editor_action].presence.to_s
    action = "save" if action.blank?

    case action
    when "save"
      save_draft_for_page!
      redirect_to editor_page_path_for(@page_key), notice: "Draft saved."
    when "preview"
      redirect_to public_preview_path_for(@page_key)
    when "publish"
      unless app_setting.page_draft_present?(@page_key)
        redirect_to editor_page_path_for(@page_key), alert: "No saved draft to publish yet."
        return
      end

      publish_draft_for_page!
      redirect_to editor_page_path_for(@page_key), notice: "Changes published."
    else
      redirect_to editor_page_path_for(@page_key), alert: "Unknown editor action."
    end
  rescue StandardError => e
    Rails.logger.error("Pages editor update failed (#{@page_key}): #{e.class} - #{e.message}")
    @page_content = app_setting.page_content(@page_key, preview: true)
    @draft_pending = app_setting.page_draft_present?(@page_key)
    @page_key = @page_key.to_s
    flash.now[:alert] = e.message
    render @page_key, status: :unprocessable_entity
  end

  private

  def set_page_key
    requested = params[:page].presence || action_name
    @page_key = normalize_page_key(requested)
  end

  def normalize_page_key(raw_value)
    key = raw_value.to_s
    key = "partners" if key == "edit"
    return key if AppSetting::EDITOR_PAGE_KEYS.include?(key)

    raise ArgumentError, "Unsupported page."
  end

  def load_page_editor_content
    @page_content = app_setting.page_content(@page_key, preview: true)
    @draft_pending = app_setting.page_draft_present?(@page_key)
  end

  def save_draft_for_page!
    previous_draft = app_setting.page_draft_content(@page_key)
    published_images = app_setting.page_content(@page_key, preview: false).fetch("images", {})

    payload = parse_payload_json
    payload = app_setting.normalize_page_payload(@page_key, payload)
    payload = attach_uploaded_images(payload)

    draft = app_setting.save_page_draft!(@page_key, payload)
    purge_replaced_images(
      previous_draft&.fetch("images", {}),
      draft.fetch("images", {}),
      protected_paths: published_images.values
    )
  end

  def publish_draft_for_page!
    old_published, new_published = app_setting.publish_page_draft!(@page_key)
    purge_replaced_images(old_published["images"], new_published["images"], protected_paths: [])
  end

  def parse_payload_json
    raw = params[:page_payload_json].to_s
    return {} if raw.blank?

    JSON.parse(raw)
  rescue JSON::ParserError
    raise ArgumentError, "Draft content is invalid. Please refresh and try again."
  end

  def attach_uploaded_images(payload)
    updated = payload.deep_dup

    app_setting.page_image_keys(@page_key).each do |key|
      file = params.dig(:images, key)
      next if file.blank?

      updated["images"][key] = save_processed_image(file)
    end

    updated
  end

  def save_processed_image(file)
    unless file.respond_to?(:content_type) && file.content_type.to_s.start_with?("image/")
      raise ArgumentError, "Only image uploads are allowed."
    end

    filename = "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(8)}.jpg"
    temp_file = Tempfile.new([ "public-page-upload", ".jpg" ], binmode: true)
    temp_file.close

    process_image_to_limit(file.tempfile.path, temp_file.path)

    if s3_uploads_enabled?
      upload_to_s3!(temp_file.path, filename)
    else
      persist_to_local_storage(temp_file.path, filename)
    end
  ensure
    temp_file&.unlink
  end

  def process_image_to_limit(source_path, destination)
    require "vips"

    image = Vips::Image.new_from_file(source_path, access: :sequential)
    image = image.flatten(background: 255) if image.has_alpha?
    image = image.colourspace("srgb")

    quality = 86
    scale = 1.0

    loop do
      render_candidate(image, destination, scale: scale, quality: quality)
      break if File.size(destination) <= MAX_IMAGE_BYTES

      if quality > 46
        quality -= 8
      elsif scale > 0.45
        scale *= 0.85
      else
        raise ArgumentError, "Image could not be reduced below 1MB. Please upload a smaller image."
      end
    end
  rescue LoadError, Vips::Error => e
    Rails.logger.warn("Vips processing failed, fallback to file size check: #{e.class} - #{e.message}")
    raw_size = File.size(source_path)
    if raw_size > MAX_IMAGE_BYTES
      raise ArgumentError, "Image processing is unavailable and file exceeds 1MB."
    end

    FileUtils.cp(source_path, destination)
  end

  def render_candidate(image, destination, scale:, quality:)
    candidate = scale < 0.999 ? image.resize(scale) : image
    candidate.write_to_file(
      destination.to_s,
      Q: quality,
      strip: true,
      optimize_coding: true,
      interlace: true
    )
  end

  def purge_replaced_images(old_images, new_images, protected_paths: [])
    old_values = old_images.is_a?(Hash) ? old_images.values : []
    new_values = new_images.is_a?(Hash) ? new_images.values : []
    locked = Array(protected_paths).map(&:to_s)

    old_values.each do |path|
      next if new_values.include?(path)
      next if locked.include?(path.to_s)

      remove_managed_image(path)
    end
  end

  def persist_to_local_storage(source_path, filename)
    upload_dir = Rails.root.join("public", "uploads", "public_pages")
    FileUtils.mkdir_p(upload_dir)
    destination = upload_dir.join(filename)
    FileUtils.cp(source_path, destination)
    "#{LOCAL_IMAGE_UPLOAD_PREFIX}#{filename}"
  end

  def upload_to_s3!(source_path, filename)
    key = "#{S3_OBJECT_PREFIX}#{filename}"

    File.open(source_path, "rb") do |io|
      s3_client.put_object(
        bucket: s3_bucket,
        key: key,
        body: io,
        content_type: "image/jpeg",
        cache_control: "public, max-age=31536000, immutable"
      )
    end

    "#{public_upload_asset_host}/#{key}"
  end

  def remove_managed_image(path)
    value = path.to_s

    if value.start_with?(LOCAL_IMAGE_UPLOAD_PREFIX)
      absolute = Rails.root.join("public", value.delete_prefix("/"))
      FileUtils.rm_f(absolute)
      return
    end

    return unless s3_uploads_enabled?

    key = s3_key_from_reference(value)
    return if key.blank?

    s3_client.delete_object(bucket: s3_bucket, key: key)
  rescue Aws::S3::Errors::NoSuchKey
    nil
  end

  def s3_uploads_enabled?
    s3_bucket.present?
  end

  def s3_bucket
    ENV["PUBLIC_UPLOAD_S3_BUCKET"].to_s.strip
  end

  def s3_region
    ENV["PUBLIC_UPLOAD_S3_REGION"].presence || ENV["AWS_REGION"].presence || "ap-southeast-2"
  end

  def public_upload_asset_host
    configured = ENV["PUBLIC_UPLOAD_ASSET_HOST"].to_s.strip
    return configured.chomp("/") if configured.present?

    "https://#{s3_bucket}.s3.#{s3_region}.amazonaws.com"
  end

  def s3_client
    @s3_client ||= begin
      require "aws-sdk-s3"

      options = { region: s3_region }
      endpoint = ENV["PUBLIC_UPLOAD_S3_ENDPOINT"].to_s.strip
      options[:endpoint] = endpoint if endpoint.present?
      options[:force_path_style] = truthy?(ENV["PUBLIC_UPLOAD_S3_FORCE_PATH_STYLE"]) if ENV.key?("PUBLIC_UPLOAD_S3_FORCE_PATH_STYLE")

      Aws::S3::Client.new(options)
    end
  end

  def s3_key_from_reference(reference)
    return nil if reference.blank?

    value = reference.to_s
    return value if value.start_with?(S3_OBJECT_PREFIX)

    begin
      uri = URI.parse(value)
    rescue URI::InvalidURIError
      return nil
    end

    return nil unless uri.host.present?

    normalized_path = uri.path.to_s.sub(%r{\A/}, "")
    return normalized_path if host_matches_asset_host?(uri.host) && normalized_path.start_with?(S3_OBJECT_PREFIX)

    return normalized_path if s3_virtual_host?(uri.host) && normalized_path.start_with?(S3_OBJECT_PREFIX)

    path_style_prefix = "#{s3_bucket}/"
    if s3_path_style_host?(uri.host) && normalized_path.start_with?(path_style_prefix)
      candidate = normalized_path.delete_prefix(path_style_prefix)
      return candidate if candidate.start_with?(S3_OBJECT_PREFIX)
    end

    nil
  end

  def host_matches_asset_host?(candidate_host)
    configured = ENV["PUBLIC_UPLOAD_ASSET_HOST"].to_s.strip
    return false if configured.blank?

    URI.parse(configured).host.to_s.casecmp?(candidate_host.to_s)
  rescue URI::InvalidURIError
    false
  end

  def s3_virtual_host?(candidate_host)
    host = candidate_host.to_s.downcase
    bucket = s3_bucket.downcase
    region = s3_region.downcase
    host == "#{bucket}.s3.#{region}.amazonaws.com" || host == "#{bucket}.s3.amazonaws.com"
  end

  def s3_path_style_host?(candidate_host)
    host = candidate_host.to_s.downcase
    region = s3_region.downcase
    host == "s3.#{region}.amazonaws.com" || host == "s3.amazonaws.com"
  end

  def truthy?(value)
    %w[1 true yes y on].include?(value.to_s.strip.downcase)
  end

  def editor_page_path_for(page_key)
    case page_key
    when "home" then edit_pages_path
    when "partners" then edit_partners_page_path
    when "builders" then edit_builders_page_path
    else edit_pages_path
    end
  end

  def public_preview_path_for(page_key)
    case page_key
    when "home" then root_path(preview: 1)
    when "partners" then partners_path(preview: 1)
    when "builders" then builders_path(preview: 1)
    else root_path(preview: 1)
    end
  end
end
