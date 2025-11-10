defmodule NetAuto.PromEx.ObservabilityPlugin do
  @moduledoc """
  Custom PromEx plugin that surfaces metrics for runner lifecycle events.
  """

  use PromEx.Plugin

  @runner_event_prefix [:net_auto, :runner]
  @liveview_event_prefix [:net_auto, :liveview]
  @chunk_event_prefix [:net_auto, :run, :chunk]
  @run_event_prefix [:net_auto, :run]

  @impl true
  def event_metrics(opts) do
    metric_prefix = Keyword.get(opts, :metric_prefix, @runner_event_prefix)

    [
      runner_event_metrics(metric_prefix),
      run_event_metrics(),
      liveview_event_metrics(),
      chunk_event_metrics()
    ]
  end

  defp runner_event_metrics(metric_prefix) do
    Event.build(:net_auto_runner_event_metrics, [
      counter(
        metric_prefix ++ [:start, :total],
        event_name: [:net_auto, :runner, :start],
        description: "Count of runner start events",
        measurement: :count,
        tags: [:device_id, :source, :requested_by]
      ),
      counter(
        metric_prefix ++ [:stop, :total],
        event_name: [:net_auto, :runner, :stop],
        description: "Count of runner stop events",
        measurement: :count,
        tags: [:device_id, :run_id, :source, :requested_by]
      ),
      counter(
        metric_prefix ++ [:error, :total],
        event_name: [:net_auto, :runner, :error],
        description: "Count of runner errors",
        measurement: :count,
        tags: [:device_id, :source, :requested_by]
      ),
      distribution(
        metric_prefix ++ [:duration, :milliseconds],
        event_name: [:net_auto, :runner, :stop],
        description: "Runner execution duration histogram (ms)",
        measurement: :duration_ms,
        reporter_options: [buckets: duration_buckets_ms()],
        tags: [:device_id, :run_id]
      ),
      last_value(
        metric_prefix ++ [:bytes, :processed],
        event_name: [:net_auto, :runner, :stop],
        description: "Bytes processed by each runner execution",
        measurement: :bytes,
        tags: [:device_id, :run_id]
      )
    ])
  end

  defp liveview_event_metrics do
    Event.build(:net_auto_liveview_event_metrics, [
      distribution(
        @liveview_event_prefix ++ [:mount, :duration, :milliseconds],
        event_name: [:net_auto, :liveview, :mount],
        description: "LiveView mount duration (ms)",
        measurement: :duration_ms,
        reporter_options: [buckets: duration_buckets_ms()],
        tags: [:view, :device_id]
      ),
      counter(
        @liveview_event_prefix ++ [:command_submitted, :total],
        event_name: [:net_auto, :liveview, :command_submitted],
        description: "Commands submitted from RunLive",
        measurement: :count,
        tags: [:device_id, :requested_by]
      )
    ])
  end

  defp chunk_event_metrics do
    Event.build(:net_auto_chunk_event_metrics, [
      counter(
        @chunk_event_prefix ++ [:appended, :total],
        event_name: [:net_auto, :run, :chunk_appended],
        description: "Chunks appended to runs",
        measurement: :count,
        tags: [:run_id, :seq]
      ),
      sum(
        @chunk_event_prefix ++ [:bytes, :total],
        event_name: [:net_auto, :run, :chunk_appended],
        description: "Total bytes appended to runs",
        measurement: :bytes,
        tags: [:run_id]
      )
    ])
  end

  defp run_event_metrics do
    Event.build(:net_auto_run_event_metrics, [
      counter(
        @run_event_prefix ++ [:created, :total],
        event_name: [:net_auto, :run, :created],
        description: "Runs created via automation",
        measurement: :count,
        tags: [:device_id, :site, :protocol]
      )
    ])
  end

  defp duration_buckets_ms do
    exponential!(1, 2, 12)
  end
end
