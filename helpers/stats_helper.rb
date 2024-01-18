# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module StatsHelper

        def stats_scribes
          attributions = 0
          scribe_ids = Set.new
          recipient_ids = Set.new
          UserOccurrence.select(:id, :user_id, :created_by)
                        .where(visible: true)
                        .where.not(created_by: User::BOT_IDS)
                        .find_in_batches(batch_size: 500_000) do |group|
            group.delete_if{ |uo| uo.user_id == uo.created_by }
            attributions += group.size
            scribe_ids.merge(group.map(&:created_by))
            recipient_ids.merge(group.map(&:user_id))
          end
          {
            scribe_ids: scribe_ids.to_a.sort,
            scribe_count: scribe_ids.size,
            attribution_count: attributions,
            recipient_count: recipient_ids.size
          }
        end

        def stats_claims
          data = UserOccurrence.select("YEAR(created) AS year, MONTH(created) AS month, count(*) AS sum")
                               .where.not(created_by: User::BOT_IDS)
                               .where(visible: true)
                               .where("created_by = user_id")
                               .where("created < DATE_SUB(CURRENT_DATE, INTERVAL DAYOFMONTH(CURRENT_DATE)-1 DAY)")
                               .group("YEAR(created), MONTH(created)")
                               .order("YEAR(created), MONTH(created)")
          total = 0
          data.map{|d| [d.year, d.month, total += d.sum] }
        end

        def stats_attributions
          data = UserOccurrence.select("YEAR(created) AS year, MONTH(created) AS month, count(*) AS sum")
                               .where.not(created_by: User::BOT_IDS)
                               .where(visible: true)
                               .where("created_by <> user_id")
                               .where("created < DATE_SUB(CURRENT_DATE, INTERVAL DAYOFMONTH(CURRENT_DATE)-1 DAY)")
                               .group("YEAR(created), MONTH(created)")
                               .order("YEAR(created), MONTH(created)")
          total = 0
          data.map{|d| [d.year, d.month, total += d.sum] }
        end

        def stats_attribution_count_from_source
          UserOccurrence.where(created_by: User::GBIF_AGENT_ID).count
        end

        def stats_rejected
          data = UserOccurrence.select("YEAR(created) AS year, MONTH(created) AS month, count(*) AS sum")
                               .where.not(created_by: User::BOT_IDS)
                               .where(visible: false)
                               .where("created < DATE_SUB(CURRENT_DATE, INTERVAL DAYOFMONTH(CURRENT_DATE)-1 DAY)")
                               .group("YEAR(created), MONTH(created)")
                               .order("YEAR(created), MONTH(created)")
          total = 0
          data.map{|d| [d.year, d.month, total += d.sum] }
        end

        def stats_profiles
          data = User.select("YEAR(created) AS year, MONTH(created) AS month, count(wikidata) AS wikidata_sum, count(orcid) AS orcid_sum")
                     .where("created < DATE_SUB(CURRENT_DATE, INTERVAL DAYOFMONTH(CURRENT_DATE)-1 DAY)")
                     .group("YEAR(created), MONTH(created)")
                     .order("YEAR(created), MONTH(created)")
          wikidata_total = 0
          orcid_total = 0
          data.map{|d| [d.year, d.month, (wikidata_total += d.wikidata_sum), (orcid_total += d.orcid_sum)] }
        end

        def stats_orcid
          User.select("COUNT(*) AS total, SUM(IF(visited, 1, 0)) AS visited, SUM(IF(is_public = true, 1, 0)) AS public, SUM(IF(zenodo_doi, 1, 0)) AS doi")
              .where.not(orcid: nil)
              .first
        end

        def stats_wikidata
          User.select("COUNT(*) AS total, SUM(IF(is_public = true, 1, 0)) AS public, SUM(IF(zenodo_doi, 1, 0)) AS doi")
              .where.not(wikidata: nil)
              .first
        end

        def stats_wikidata_merged
          DestroyedUser.where("identifier LIKE 'Q%'").count
        end

        def stats_datasets
          Dataset.select("COUNT(*) AS total, SUM(IF(frictionless_created_at, 1, 0)) AS frictionless, SUM(IF(source_attribution_count, 1, 0)) AS identifiers, SUM(IF(zenodo_concept_doi, 1, 0)) AS zenodo")
                 .first
        end

      end
    end
  end
end
