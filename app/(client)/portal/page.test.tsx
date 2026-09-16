// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, expect, test, vi } from "vitest";

const mocks = vi.hoisted(() => ({ data: vi.fn() }));

vi.mock("@/lib/auth/profile", () => ({
  requireClientProfile: async () => ({ fullName: "Cliente" }),
}));
vi.mock("@/lib/portal/queries", () => ({
  getPortalPageData: mocks.data,
}));
vi.mock("@/components/app-header", () => ({
  AppHeader: () => <header>Portal</header>,
}));

import PortalPage from "./page";

afterEach(cleanup);

function pageData(attentionStatus: "none" | "attention") {
  return {
    clientName: "Empresa",
    updatedThrough: "2026-09-14",
    applications: [
      {
        date: "2026-09-14",
        applications: [
          {
            statusDate: "2026-09-14",
            generatorId: "g",
            generatorIdentifier: "Gerador",
            locationId: "l",
            locationName: "Unidade",
            coldRoomId: "r",
            coldRoomName: "Câmara",
            startedAt: "07:00:00",
            endedAt: "07:30:00",
            maxMeasuredPowerW: "96",
            attentionStatus,
          },
        ],
      },
    ],
    applicationCount: 1,
    generatorCount: 1,
    attentionCount: attentionStatus === "attention" ? 1 : 0,
    filters: {
      month: "2026-09",
      startDate: "2026-09-01",
      endDate: "2026-09-30",
    },
    options: { locations: [], coldRooms: [], generators: [] },
    hasPublishedStatus: true,
  };
}

test.each(["none", "attention"] as const)(
  "renders the monthly application agenda without technical evidence for %s",
  async (attentionStatus) => {
    mocks.data.mockResolvedValue(pageData(attentionStatus));

    const { container } = render(
      await PortalPage({ searchParams: Promise.resolve({}) }),
    );

    expect(
      screen.getByRole("heading", { name: "setembro de 2026" }),
    ).toBeTruthy();
    expect(screen.getByText("Aplicações registradas")).toBeTruthy();
    expect(screen.getAllByText("Gerador").length).toBeGreaterThan(0);
    expect(screen.getByText("07:00 – 07:30")).toBeTruthy();
    expect(screen.getByText("96 W")).toBeTruthy();
    expect(screen.getByRole("link", { name: "Mês anterior" })).toHaveProperty(
      "href",
      expect.stringContaining("month=2026-08"),
    );
    expect(container.innerHTML).not.toMatch(
      /Evidência de potência|power_evidence|power_profile|device_id|device_name/,
    );

    if (attentionStatus === "attention") {
      expect(screen.getByRole("status").textContent).toContain(
        "Aplicação registrada — atenção necessária",
      );
    } else {
      expect(screen.queryByRole("status")).toBeNull();
      expect(screen.getByText("Aplicação registrada")).toBeTruthy();
    }
  },
);

test("renders the empty state for a month without registered applications", async () => {
  mocks.data.mockResolvedValue({
    ...pageData("none"),
    applications: [],
    applicationCount: 0,
    generatorCount: 0,
  });

  render(await PortalPage({ searchParams: Promise.resolve({}) }));

  expect(
    screen.getByText("Nenhuma aplicação registrada em setembro de 2026"),
  ).toBeTruthy();
});
