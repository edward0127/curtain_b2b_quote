require "test_helper"
require Rails.root.join("db/migrate/20260314100000_convert_legacy_quote_statuses_to_cancelled")

class ConvertLegacyQuoteStatusesToCancelledMigrationTest < ActiveSupport::TestCase
  test "migration converts only legacy statuses and is idempotent" do
    legacy_quote = quote_requests(:one)
    legacy_quote.update_columns(status: QuoteRequest.statuses.fetch("reviewed"), submitted_at: nil, cancelled_at: nil)

    active_quote = quote_requests(:two)
    active_quote.update_columns(
      status: QuoteRequest.statuses.fetch("completed"),
      submitted_at: Time.current,
      cancelled_at: nil
    )

    migration = ConvertLegacyQuoteStatusesToCancelled.new
    migration.up

    legacy_quote.reload
    assert_equal "cancelled", legacy_quote.status
    assert_not_nil legacy_quote.cancelled_at
    assert_not_nil legacy_quote.submitted_at

    active_quote.reload
    assert_equal "completed", active_quote.status

    cancelled_at_after_first_run = legacy_quote.cancelled_at
    migration.up
    legacy_quote.reload
    assert_equal "cancelled", legacy_quote.status
    assert_equal cancelled_at_after_first_run.to_i, legacy_quote.cancelled_at.to_i
  end
end
