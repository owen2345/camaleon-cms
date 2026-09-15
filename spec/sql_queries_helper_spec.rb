# frozen_string_literal: true

# The specs that pin how often a record's metas are read count with metas_selects, so it must count every
# SELECT against the metas table, whatever its prefix and whatever Rails puts before the statement, such as
# a query log comment, and nothing else, not even a table whose name only starts with metas.
RSpec.describe SqlQueriesHelper do
  def issue(statements)
    statements.each do |sql|
      ActiveSupport::Notifications.instrument('sql.active_record', sql: sql, name: 'Probe Load')
    end
  end

  def selects_among(*statements)
    metas_selects { issue(statements) }
  end

  it 'counts a SELECT from the metas table, however it is quoted, prefixed or introduced' do
    selects = selects_among(
      'SELECT "metas".* FROM "metas" WHERE "metas"."objectid" = 1',
      'SELECT `cama_metas`.* FROM `cama_metas` WHERE `cama_metas`.`objectid` = 1',
      '/*application:Dummy,controller:posts*/ SELECT "metas".* FROM "metas"',
      "\n  SELECT 1 AS one FROM \"metas\" LIMIT 1"
    )

    expect(selects.size).to eq(4)
  end

  it 'counts neither another statement on the metas table nor a table whose name only starts with metas' do
    selects = selects_among(
      'DELETE FROM "metas" WHERE "metas"."id" = 1',
      'SELECT "metastore".* FROM "metastore"',
      'SELECT "posts".* FROM "posts" INNER JOIN "metas" ON "metas"."objectid" = "posts"."id"'
    )

    expect(selects).to be_empty
  end

  it 'counts a long eager-loading SELECT from the metas table and not a long one from another table' do
    ids = (1..2000).to_a.join(', ')
    selects = selects_among(
      %(SELECT "metas".* FROM "metas" WHERE "metas"."objectid" IN (#{ids})),
      %(SELECT "posts".* FROM "posts" WHERE "posts"."id" IN (#{ids}))
    )

    expect(selects.size).to eq(1)
  end

  it 'collects only the statements that match every pattern of a list' do
    queries = sql_queries(matching: [/\ASELECT\b/, /"posts"/]) do
      issue(['SELECT "posts".* FROM "posts"', 'SELECT "metas".* FROM "metas"', 'DELETE FROM "posts"'])
    end

    expect(queries).to eq(['SELECT "posts".* FROM "posts"'])
  end
end
