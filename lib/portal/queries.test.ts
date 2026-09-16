import { beforeEach, expect, test, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  profile: vi.fn(),
  client: vi.fn(),
  rpc: vi.fn(),
  from: vi.fn(),
}));

vi.mock("@/lib/auth/profile", () => ({ requireClientProfile: mocks.profile }));
vi.mock("@/lib/supabase/server", () => ({ createClient: mocks.client }));

import { getPortalPageData, resolvePortalFilters } from "./queries";

const row = {
  client_id: "client",
  location_id: "location",
  cold_room_id: "room",
  generator_id: "generator",
  status_date: "2026-09-14",
  application_started_at: "07:00:00",
  application_ended_at: "07:30:00",
  max_measured_power_w: "96",
  attention_status: "none",
};

function response(data: unknown) {
  const result = { data, error: null };
  return {
    ...result,
    select: () => response(data),
    eq: () => response(data),
    order: () => response(data),
    limit: () => response(data),
    maybeSingle: () => Promise.resolve(result),
  };
}

beforeEach(() => {
  vi.resetAllMocks();
  mocks.profile.mockResolvedValue({ clientId: "client" });
  mocks.client.mockResolvedValue({ from: mocks.from, rpc: mocks.rpc });
  mocks.from.mockImplementation((table: string) => {
    const data: Record<string, unknown> = {
      clients: { legal_name: "Empresa" },
      locations: [{ id: "location", name: "Unidade" }],
      cold_rooms: [{ id: "room", location_id: "location", name: "Câmara" }],
      generators: [{ id: "generator", identifier: "Gerador" }],
    };
    if (!(table in data)) throw new Error("Unexpected table " + table);
    return response(data[table]);
  });
  mocks.rpc.mockImplementation((_name, args) =>
    args === undefined ? response(row) : response([row]),
  );
});

test("resolves the latest published month and supports legacy date links", () => {
  expect(resolvePortalFilters({}, "2026-09-14")).toMatchObject({
    month: "2026-09",
    startDate: "2026-09-01",
    endDate: "2026-09-30",
  });
  expect(
    resolvePortalFilters({ startDate: "2026-08-01", endDate: "2026-08-23" }, "2026-09-14"),
  ).toMatchObject({
    month: "2026-08",
    startDate: "2026-08-01",
    endDate: "2026-08-31",
  });
});

test.each(["none", "attention"])(
  "maps only sanitized registered applications for %s",
  async (attention) => {
    mocks.rpc.mockImplementation((_name, args) =>
      args === undefined
        ? response(row)
        : response([
            { ...row, attention_status: attention, device_id: "SECRET" },
          ]),
    );

    const data = await getPortalPageData({ month: "2026-09" });

    expect(data.applications).toEqual([
      expect.objectContaining({
        date: "2026-09-14",
        applications: [
          expect.objectContaining({
            generatorIdentifier: "Gerador",
            startedAt: "07:00:00",
            endedAt: "07:30:00",
            maxMeasuredPowerW: "96",
            attentionStatus: attention,
          }),
        ],
      }),
    ]);
    expect(data.applicationCount).toBe(1);
    expect(data.generatorCount).toBe(1);
    expect(data.attentionCount).toBe(attention === "attention" ? 1 : 0);
    expect(JSON.stringify(data)).not.toMatch(/SECRET|device_id|power_profile/);
    expect(mocks.from.mock.calls.flat()).not.toContain("client_daily_status");
  },
);

test("passes the selected month filters and paginates using the RPC offset", async () => {
  mocks.rpc.mockImplementation((_name, args) =>
    args === undefined
      ? response(row)
      : response(
          args.p_offset === 0
            ? Array.from({ length: 1000 }, () => row)
            : [],
        ),
  );

  await getPortalPageData({
    month: "2026-09",
    generatorId: "generator",
  });

  expect(mocks.rpc).toHaveBeenCalledWith(
    "list_client_application_details",
    expect.objectContaining({
      p_start_date: "2026-09-01",
      p_end_date: "2026-09-30",
      p_generator_id: "generator",
      p_offset: 1000,
    }),
  );
});

test("keeps multiple applications from the same generator on the same day", async () => {
  mocks.rpc.mockImplementation((_name, args) =>
    args === undefined
      ? response(row)
      : response([
          row,
          {
            ...row,
            application_started_at: "09:00:00",
            application_ended_at: "09:30:00",
          },
        ]),
  );

  const data = await getPortalPageData({ month: "2026-09" });

  expect(data.applications).toHaveLength(1);
  expect(data.applications[0].applications).toHaveLength(2);
  expect(data.applicationCount).toBe(2);
  expect(data.generatorCount).toBe(1);
});

test("uses the daily status contract until the application-details migration is applied", async () => {
  mocks.rpc.mockImplementation((name, args) => {
    if (args === undefined) return response(row);
    if (name === "list_client_application_details") {
      return {
        data: null,
        error: {
          code: "PGRST202",
          message: "Could not find list_client_application_details",
        },
      };
    }

    return response([
      {
        ...row,
        application_status: "registered",
      },
    ]);
  });

  const data = await getPortalPageData({ month: "2026-09" });

  expect(data.applications[0].applications[0]).toMatchObject({
    startedAt: null,
    endedAt: null,
    maxMeasuredPowerW: null,
  });
  expect(mocks.rpc).toHaveBeenCalledWith(
    "list_client_application_status",
    expect.objectContaining({ p_start_date: "2026-09-01" }),
  );
});

test("requires authorization before accessing data", async () => {
  mocks.profile.mockRejectedValue(new Error("Unauthorized"));

  await expect(getPortalPageData({})).rejects.toThrow("Unauthorized");
  expect(mocks.client).not.toHaveBeenCalled();
});

test("sanitizes RPC errors", async () => {
  mocks.rpc.mockReturnValue({
    ...response(null),
    error: { message: "secret database error" },
    limit: () => ({
      maybeSingle: () => ({
        data: null,
        error: { message: "secret database error" },
      }),
    }),
  });

  await expect(getPortalPageData({})).rejects.toThrow(
    "Não foi possível carregar a atualização dos registros.",
  );
});
