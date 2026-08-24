import { statusFilters, type StatusFilter } from "@/lib/operations/constants";

type ListFiltersProps = {
  status: StatusFilter;
  query?: string;
  withSearch?: boolean;
};

export function ListFilters({
  status,
  query = "",
  withSearch = false,
}: ListFiltersProps) {
  return (
    <form className="list-filters">
      {withSearch ? (
        <label>
          Buscar
          <input
            defaultValue={query}
            name="q"
            placeholder="Nome ou CNPJ"
            type="search"
          />
        </label>
      ) : null}

      <label>
        Status
        <select defaultValue={status} name="status">
          {statusFilters.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
      </label>

      <button className="secondary-button" type="submit">
        Filtrar
      </button>
    </form>
  );
}
