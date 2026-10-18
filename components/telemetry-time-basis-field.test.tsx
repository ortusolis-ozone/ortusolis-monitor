// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, expect, test } from "vitest";
import { TelemetryTimeBasisField } from "./telemetry-time-basis-field";

afterEach(cleanup);

test("the selector follows the persisted preference after a server refresh", () => {
  const view = render(<TelemetryTimeBasisField value="utc" required={false} />);
  const field = () => screen.getByRole("combobox", { name: "Horário dos arquivos de telemetria" }) as HTMLSelectElement;
  expect(field().value).toBe("utc");
  view.rerender(<TelemetryTimeBasisField value="location" required={false} />);
  expect(field().value).toBe("location");
  view.rerender(<TelemetryTimeBasisField value={null} required={false} />);
  expect(field().value).toBe("");
});

test("a new location requires an explicit choice with no silent default", () => {
  render(<TelemetryTimeBasisField />);
  const field = screen.getByRole("combobox", { name: "Horário dos arquivos de telemetria" }) as HTMLSelectElement;
  expect(field.value).toBe("");
  expect(field.required).toBe(true);
  expect(field.checkValidity()).toBe(false);
});
