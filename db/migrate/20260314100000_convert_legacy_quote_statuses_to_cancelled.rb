class ConvertLegacyQuoteStatusesToCancelled < ActiveRecord::Migration[8.1]
  LEGACY_STATUS_VALUES = [0, 1, 2, 3, 4, 5].freeze
  CANCELLED_STATUS_VALUE = 10

  def up
    now = connection.quote(Time.current)

    execute <<~SQL.squish
      UPDATE quote_requests
      SET status = #{CANCELLED_STATUS_VALUE},
          cancelled_at = COALESCE(cancelled_at, #{now}),
          submitted_at = COALESCE(submitted_at, created_at, #{now}),
          updated_at = #{now}
      WHERE status IN (#{LEGACY_STATUS_VALUES.join(",")})
    SQL
  end

  def down
    # no-op: legacy statuses are intentionally retired
  end
end
