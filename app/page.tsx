import { redirect } from "next/navigation";

import { getCurrentProfile, homePathForRole } from "@/lib/auth/profile";

export default async function Home() {
  const profile = await getCurrentProfile();

  if (!profile) {
    redirect("/login");
  }

  redirect(homePathForRole(profile.role));
}
