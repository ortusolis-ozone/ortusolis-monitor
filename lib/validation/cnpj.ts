export function normalizeCnpj(value: string) {
  return value.toUpperCase().replace(/[.\/\-\s]/g, "");
}

function calculateDigit(base: string, weights: number[]) {
  const sum = base
    .split("")
    // Receita Federal: valor ASCII do caractere menos 48, inclusive para letras.
    .reduce(
      (total, digit, index) => total + (digit.charCodeAt(0) - 48) * weights[index],
      0,
    );
  const remainder = sum % 11;

  return remainder < 2 ? 0 : 11 - remainder;
}

export function isValidCnpj(value: string) {
  const cnpj = normalizeCnpj(value);

  if (!/^[A-Z0-9]{12}[0-9]{2}$/.test(cnpj) || /^(\d)\1{13}$/.test(cnpj)) {
    return false;
  }

  const firstDigit = calculateDigit(
    cnpj.slice(0, 12),
    [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2],
  );
  const secondDigit = calculateDigit(
    `${cnpj.slice(0, 12)}${firstDigit}`,
    [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2],
  );

  return cnpj.endsWith(`${firstDigit}${secondDigit}`);
}

export function formatCnpj(value: string) {
  const cnpj = normalizeCnpj(value);

  if (cnpj.length !== 14) {
    return value;
  }

  return cnpj.replace(
    /^([A-Z0-9]{2})([A-Z0-9]{3})([A-Z0-9]{3})([A-Z0-9]{4})(\d{2})$/,
    "$1.$2.$3/$4-$5",
  );
}
