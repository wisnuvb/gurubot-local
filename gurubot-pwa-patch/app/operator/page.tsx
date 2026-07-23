import { redirect } from "next/navigation";

/** Opsional: ganti static /operator/index.html dengan halaman React penuh nanti */
export default function OperatorPage() {
  redirect("/operator/index.html");
}
