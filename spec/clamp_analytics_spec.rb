# frozen_string_literal: true

require "clamp_analytics"

RSpec.describe Clamp::Analytics do
  let(:captured) { [] }
  let(:transport) do
    proc do |url, headers, body|
      captured << { url: url, headers: headers, body: body }
      { status: 200, body: "" }
    end
  end

  before do
    described_class.reset!
    described_class.transport = transport
  end

  describe "init then track happy path" do
    it "sends payload to /e/s with the right headers" do
      described_class.init(project_id: "proj_test", api_key: "sk_proj_test")
      expect(described_class.track("signup", properties: { plan: "pro" })).to be true

      expect(captured.length).to eq(1)
      request = captured.first
      expect(request[:url]).to eq("https://api.clamp.sh/e/s")
      expect(request[:headers]["x-clamp-key"]).to eq("sk_proj_test")
      expect(request[:headers]["content-type"]).to eq("application/json")

      payload = JSON.parse(request[:body])
      expect(payload["p"]).to eq("proj_test")
      expect(payload["name"]).to eq("signup")
      expect(payload["properties"]).to eq("plan" => "pro")
    end
  end

  describe "track without init" do
    it "raises NotInitializedError" do
      expect { described_class.track("signup") }.to raise_error(Clamp::Analytics::NotInitializedError)
    end
  end

  describe "property value types" do
    it "round-trips string, integer, float, boolean, and Money" do
      described_class.init(project_id: "proj_test", api_key: "sk_proj_test")
      described_class.track("purchase", properties: {
        plan: "pro",
        items: 3,
        discount: 0.15,
        refunded: false,
        total: Clamp::Analytics::Money.new(29.00, "USD")
      })

      payload = JSON.parse(captured.first[:body])
      props = payload["properties"]
      expect(props["plan"]).to eq("pro")
      expect(props["items"]).to eq(3)
      expect(props["discount"]).to eq(0.15)
      expect(props["refunded"]).to be false
      expect(props["total"]).to eq("amount" => 29.00, "currency" => "USD")
    end
  end

  describe "unsupported property type" do
    it "raises ArgumentError" do
      described_class.init(project_id: "proj_test", api_key: "sk_proj_test")
      expect do
        described_class.track("event", properties: { items: [1, 2, 3] })
      end.to raise_error(ArgumentError, /unsupported type/)
    end
  end

  describe "non-2xx response" do
    let(:transport) do
      proc do |_url, _headers, _body|
        { status: 401, body: "invalid api key" }
      end
    end

    it "raises HTTPError with status and body" do
      described_class.init(project_id: "proj_test", api_key: "sk_proj_bad")
      begin
        described_class.track("signup")
        fail "expected HTTPError"
      rescue Clamp::Analytics::HTTPError => e
        expect(e.status_code).to eq(401)
        expect(e.body).to include("invalid api key")
      end
    end
  end

  describe "endpoint override" do
    it "respects a custom endpoint" do
      described_class.init(project_id: "proj_test", api_key: "sk_proj_test", endpoint: "https://staging.clamp.example")
      described_class.track("signup")
      expect(captured.first[:url]).to eq("https://staging.clamp.example/e/s")
    end
  end

  describe "optional fields when provided" do
    it "sends anonymousId and timestamp" do
      described_class.init(project_id: "proj_test", api_key: "sk_proj_test")
      ts = Time.utc(2026, 4, 29, 12, 0, 0)
      described_class.track("signup", anonymous_id: "aid_xyz", timestamp: ts)

      payload = JSON.parse(captured.first[:body])
      expect(payload["anonymousId"]).to eq("aid_xyz")
      expect(payload["timestamp"]).to eq("2026-04-29T12:00:00Z")
    end
  end

  describe "optional fields when absent" do
    it "omits anonymousId and properties; timestamp defaults to now-UTC" do
      described_class.init(project_id: "proj_test", api_key: "sk_proj_test")
      described_class.track("signup")

      payload = JSON.parse(captured.first[:body])
      expect(payload).not_to have_key("anonymousId")
      expect(payload).not_to have_key("properties")
      expect(payload["timestamp"]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end
  end

  describe "string timestamp" do
    it "is passed through unchanged" do
      described_class.init(project_id: "proj_test", api_key: "sk_proj_test")
      described_class.track("signup", timestamp: "2026-04-29T12:00:00Z")

      payload = JSON.parse(captured.first[:body])
      expect(payload["timestamp"]).to eq("2026-04-29T12:00:00Z")
    end
  end

  describe "non-UTC Time" do
    it "is normalized to UTC" do
      described_class.init(project_id: "proj_test", api_key: "sk_proj_test")
      ts = Time.new(2026, 4, 29, 14, 0, 0, "+02:00")
      described_class.track("signup", timestamp: ts)

      payload = JSON.parse(captured.first[:body])
      expect(payload["timestamp"]).to end_with("Z")
      expect(payload["timestamp"]).to eq("2026-04-29T12:00:00Z")
    end
  end

  describe "capture_error" do
    before do
      described_class.init(project_id: "proj_test", api_key: "sk_proj_test")
    end

    it "sends a $error event with message, type, stack, and handled flag" do
      begin
        raise StandardError, "checkout failed: invalid plan"
      rescue StandardError => e
        described_class.capture_error(e, context: { plan: "ultra", retry: 1 })
      end

      payload = JSON.parse(captured.first[:body])
      expect(payload["name"]).to eq("$error")
      props = payload["properties"]
      expect(props["error.message"]).to eq("checkout failed: invalid plan")
      expect(props["error.type"]).to eq("StandardError")
      expect(props["error.stack"]).to include("clamp_analytics_spec.rb")
      expect(props["error.handled"]).to be true
      expect(props["plan"]).to eq("ultra")
      expect(props["retry"]).to eq(1)
    end

    it "ignores a 'handled' key in context" do
      described_class.capture_error(RuntimeError.new("oops"), context: { handled: false, ok: true })
      payload = JSON.parse(captured.first[:body])
      expect(payload["properties"]["error.handled"]).to be true
      expect(payload["properties"]["ok"]).to be true
    end
  end
end
