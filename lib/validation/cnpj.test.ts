import { describe, expect, it } from "vitest";

import { formatCnpj, isValidCnpj, normalizeCnpj } from "./cnpj";

describe("CNPJ numérico e alfanumérico", () => {
  it.each([
    "04252011000110",
    "04.252.011/0001-10",
    "12.ABC.345/01DE-35", // Exemplo do manual da Receita Federal.
    "12abc34501de35",
    "00.000.000/E08G-12", // Primeiro CNPJ alfanumérico emitido.
  ])("valida %s", (value) => {
    expect(isValidCnpj(value)).toBe(true);
  });

  it.each([
    "", "00000000000000", "11111111111111", "12ABC34501DE34",
    "12ABC34501DE3A", "12ABC34501DE3", "12ABC34501DE350",
    "12ABC34501DÉ35", "12ABC34501DE35!", "04@252011000110",
  ])("rejeita %s", (value) => {
    expect(isValidCnpj(value)).toBe(false);
  });

  it("remove máscara e espaços e converte letras para maiúsculas", () => {
    expect(normalizeCnpj(" 12.abc.345/01de-35 ")).toBe("12ABC34501DE35");
    expect(normalizeCnpj("abc.345")).toBe("ABC345");
  });

  it("formata os dois padrões e preserva entradas incompletas", () => {
    expect(formatCnpj("04252011000110")).toBe("04.252.011/0001-10");
    expect(formatCnpj("12abc34501de35")).toBe("12.ABC.345/01DE-35");
    expect(formatCnpj("12ABC")).toBe("12ABC");
  });
});
