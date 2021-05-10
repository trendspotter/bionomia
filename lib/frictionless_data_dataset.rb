# encoding: utf-8
require_relative "frictionless_data"

module Bionomia
  class FrictionlessDataDataset < FrictionlessData

    def initialize(uuid:, output_directory:)
      @dataset = Dataset.find_by_datasetKey(uuid) rescue nil
      raise ArgumentError, 'Dataset not found' if @dataset.nil?
      super
    end

    def descriptor
      license_name = ""
      if @dataset.license.include?("/zero/1.0/")
        license_name = "public-domain-dedication"
      elsif @dataset.license.include?("/by/4.0/")
        license_name = "cc-by-4.0"
      elsif @dataset.license.include?("/by-nc/4.0/")
        license_name = "cc-by-nc-4.0"
      end

      {
        name: "bionomia-attributions",
        id: @uuid,
        licenses: [
          {
            name: license_name,
            path: @dataset.license
          }
        ],
        profile: "tabular-data-package",
        title: "ATTRIBUTIONS MADE FOR: #{@dataset.title}",
        description: "#{@dataset.description}",
        datasetKey: @dataset.datasetKey,
        homepage: "https://bionomia.net/dataset/#{@dataset.datasetKey}",
        created: Time.now.to_time.iso8601,
        sources: [
          {
            title: "#{@dataset.title}",
            path: "https://doi.org/#{@dataset.doi}"
          }
        ],
        keywords: [
          "specimen",
          "museum",
          "collection",
          "credit",
          "attribution",
          "bionomia"
        ],
        image: "https://bionomia.net/images/logo.png",
        resources: []
      }
    end

    def add_data
      users = File.open(File.join(@folder, users_file), "ab")
      occurrences = File.open(File.join(@folder, occurrences_file), "ab")
      attributions = File.open(File.join(@folder, attributions_file), "ab")

      fields = [
        "user_occurrences.id",
        "user_occurrences.user_id",
        "user_occurrences.occurrence_id",
        "user_occurrences.action",
        "user_occurrences.visible",
        "user_occurrences.created AS createdDateTime",
        "user_occurrences.updated AS modifiedDateTime",
        "users.id AS u_id",
        "users.given AS u_given",
        "users.family AS u_family",
        "users.date_born_precision AS u_date_born_precision",
        "users.date_died_precision AS u_date_died_precision",
        "users.date_born AS u_date_born",
        "users.date_died AS u_date_died",
        "users.other_names AS u_other_names",
        "users.wikidata AS u_wikidata",
        "users.orcid AS u_orcid",
        "claimants_user_occurrences.given AS createdGiven",
        "claimants_user_occurrences.family AS createdFamily",
        "claimants_user_occurrences.orcid AS createdORCID",
      ]
      fields.concat((["gbifID"] + Occurrence.accepted_fields).map{|a| "occurrences.#{a} AS occ_#{a}"})

      gbif_ids = Set.new
      user_ids = Set.new

      @dataset.user_occurrences
              .where(users: { is_public: true })
              .select(fields).find_each(batch_size: 10_000) do |o|
        next if !o.visible

        # Add users.csv
        if !user_ids.include?(o.u_id)
          aliases = o.u_other_names.split("|").to_s if !o.u_other_names.blank?
          uri = !o.u_orcid.nil? ? "https://orcid.org/#{o.u_orcid}" : "http://www.wikidata.org/entity/#{o.u_wikidata}"
          data = [
            o.u_id,
            [o.u_given, o.u_family].join(" "),
            o.u_family,
            o.u_given,
            aliases,
            uri,
            o.u_orcid,
            o.u_wikidata,
            o.u_date_born,
            o.u_date_born_precision,
            o.u_date_died,
            o.u_date_died_precision
          ]
          users << CSV::Row.new(users_header, data).to_s
          user_ids << o.u_id
        end

        # Add attributions.csv
        uri = !o.u_orcid.nil? ? "https://orcid.org/#{o.u_orcid}" : "http://www.wikidata.org/entity/#{o.u_wikidata}"
        identified_uri = o.action.include?("identified") ? uri : nil
        recorded_uri = o.action.include?("recorded") ? uri : nil
        created_name = [o.createdGiven, o.createdFamily].join(" ")
        created_orcid = !o.createdORCID.blank? ? "https://orcid.org/#{o.createdORCID}" : nil
        created_date_time = o.createdDateTime.to_time.iso8601
        modified_date_time = !o.modifiedDateTime.blank? ? o.modifiedDateTime.to_time.iso8601 : nil
        data = [
          o.user_id,
          o.occurrence_id,
          identified_uri,
          recorded_uri,
          created_name,
          created_orcid,
          created_date_time,
          modified_date_time
        ]
        attributions << CSV::Row.new(attributions_header, data).to_s

        # Skip occurrences if already added to file
        next if gbif_ids.include?(o.occ_gbifID)

        # Add occurrences.csv
        data = o.attributes.select{|k,v| k.start_with?("occ_")}.values
        occurrences << CSV::Row.new(occurrences_header, data).to_s
        gbif_ids << o.occ_gbifID
      end

      users.close
      occurrences.close
      attributions.close
    end

    def add_problem_collector_data
      problems = File.open(File.join(@folder, problem_collectors_file), "ab")
      fields = [
        :id,
        :visible,
        :occurrence_id,
        :user_id,
        "users.wikidata",
        "users.date_born",
        "users.date_born_precision",
        "users.date_died",
        "users.date_died_precision",
        "occurrences.eventDate",
        "occurrences.eventDate_processed"
      ]

      @dataset.collected_before_birth_after_death
              .select(fields)
              .find_each do |o|
                next if !o.visible
        data = [
          o.occurrence_id,
          o.user_id,
          o.wikidata,
          o.date_born,
          o.date_born_precision,
          o.date_died,
          o.date_died_precision,
          o.eventDate
        ]
        problems << CSV::Row.new(problems_collector_header, data).to_s
      end
      problems.close
    end

  end

end
