export type AccountActionState = {
  status: "idle" | "error" | "success";
  message: string;
  fieldErrors?: Record<string, string>;
};

export const initialAccountActionState: AccountActionState = {
  status: "idle",
  message: "",
};

export function accountFieldError(
  field: string,
  message: string,
): AccountActionState {
  return {
    status: "error",
    message: "Revise o campo destacado.",
    fieldErrors: { [field]: message },
  };
}
