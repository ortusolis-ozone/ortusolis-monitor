export type OperationalActionState = {
  status: "idle" | "error" | "success";
  message: string;
  fieldErrors?: Record<string, string>;
};

export const initialOperationalActionState: OperationalActionState = {
  status: "idle",
  message: "",
};

export function fieldError(
  field: string,
  message: string,
): OperationalActionState {
  return {
    status: "error",
    message: "Revise o campo destacado.",
    fieldErrors: { [field]: message },
  };
}
