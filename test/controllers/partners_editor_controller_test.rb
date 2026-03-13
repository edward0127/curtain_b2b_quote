require "test_helper"

class PartnersEditorControllerTest < ActionDispatch::IntegrationTest
  test "requires login" do
    get edit_pages_url
    assert_redirected_to new_user_session_url
  end

  test "non-admin cannot access editor" do
    sign_in users(:customer)

    get edit_pages_url
    assert_redirected_to root_url
  end

  test "admin can view editors for all pages" do
    sign_in users(:admin)

    get edit_pages_url
    assert_response :success

    get edit_partners_page_url
    assert_response :success
    assert_select "p", text: /Edit mode is enabled/

    get edit_builders_page_url
    assert_response :success
  end

  test "admin can save draft changes" do
    sign_in users(:admin)
    setting = AppSetting.current
    payload = setting.partners_page_content(preview: false)
    payload["texts"]["hero_title"] = "Draft Saved Heading"

    patch update_page_editor_url(page: "partners"), params: {
      page_payload_json: payload.to_json,
      editor_action: "save"
    }

    assert_redirected_to edit_partners_page_url
    setting.reload
    assert_equal "Draft Saved Heading", setting.partners_page_content(preview: true).dig("texts", "hero_title")
    assert setting.partners_page_draft_json.present?
  end

  test "preview action redirects to preview url" do
    sign_in users(:admin)
    setting = AppSetting.current
    setting.update!(partners_page_draft_json: nil)
    payload = setting.partners_page_content(preview: false)
    payload["texts"]["hero_title"] = "Unsaved Preview Heading"

    patch update_page_editor_url(page: "partners"), params: {
      page_payload_json: payload.to_json,
      editor_action: "preview"
    }

    assert_redirected_to partners_url(preview: 1)
    setting.reload
    assert_nil setting.partners_page_draft_json
  end

  test "publish action requires a saved draft" do
    sign_in users(:admin)
    setting = AppSetting.current
    setting.update!(partners_page_draft_json: nil)
    original = setting.partners_page_content(preview: false).dig("texts", "hero_title")

    patch update_page_editor_url(page: "partners"), params: {
      page_payload_json: "{}",
      editor_action: "publish"
    }

    assert_redirected_to edit_partners_page_url
    setting.reload
    assert_equal original, setting.partners_page_content(preview: false).dig("texts", "hero_title")
  end

  test "publish action updates published content and clears draft" do
    sign_in users(:admin)
    setting = AppSetting.current
    payload = setting.partners_page_content(preview: false)
    payload["texts"]["hero_title"] = "Published Heading"

    patch update_page_editor_url(page: "partners"), params: {
      page_payload_json: payload.to_json,
      editor_action: "save"
    }

    patch update_page_editor_url(page: "partners"), params: {
      page_payload_json: "{}",
      editor_action: "publish"
    }

    assert_redirected_to edit_partners_page_url
    setting.reload
    assert_nil setting.partners_page_draft_json
    assert_equal "Published Heading", setting.partners_page_content(preview: false).dig("texts", "hero_title")
  end

  test "publish uses last saved draft and ignores unsaved payload" do
    sign_in users(:admin)
    setting = AppSetting.current
    payload = setting.partners_page_content(preview: false)
    payload["texts"]["hero_title"] = "Saved Draft Title"

    patch update_page_editor_url(page: "partners"), params: {
      page_payload_json: payload.to_json,
      editor_action: "save"
    }

    unsaved_payload = payload.deep_dup
    unsaved_payload["texts"]["hero_title"] = "Unsaved Browser Title"

    patch update_page_editor_url(page: "partners"), params: {
      page_payload_json: unsaved_payload.to_json,
      editor_action: "publish"
    }

    setting.reload
    assert_equal "Saved Draft Title", setting.partners_page_content(preview: false).dig("texts", "hero_title")
  end

  test "missing editor action defaults to save" do
    sign_in users(:admin)
    setting = AppSetting.current
    payload = setting.partners_page_content(preview: false)
    payload["texts"]["hero_title"] = "Default Save Action Heading"

    patch update_page_editor_url(page: "partners"), params: {
      page_payload_json: payload.to_json
    }

    assert_redirected_to edit_partners_page_url
    setting.reload
    assert_equal "Default Save Action Heading", setting.partners_page_content(preview: true).dig("texts", "hero_title")
  end
end
