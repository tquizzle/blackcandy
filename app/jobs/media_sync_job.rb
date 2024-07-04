# frozen_string_literal: true

class MediaSyncJob < ApplicationJob
  include BlackCandy::Configurable

  has_config :parallel_processor_count, default: Parallel.processor_count, env_prefix: "media_sync"

  queue_as :critical

  # Limits the concurrency to 1 to prevent inconsistent media syncing data.
  limits_concurrency to: 1, key: :media_sync

  before_perform do
    Media.syncing = true
  end

  after_perform do |job|
    sync_type = job.arguments.first

    Media.syncing = false
    Media.fetch_external_metadata unless sync_type == :removed
  end

  def perform(type, file_paths = [])
    parallel_processor_count = self.class.config.parallel_processor_count
    grouped_file_paths = file_paths.in_groups(parallel_processor_count, false).compact_blank

    Parallel.each grouped_file_paths, in_processes: parallel_processor_count do |paths|
      Media.sync(type, paths)
    end
  end
end
