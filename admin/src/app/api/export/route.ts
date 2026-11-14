import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

const types = new Set(["users", "reports", "audit"]);

function csvCell(value: unknown): string {
  if (value === null || value === undefined) return "";
  const text = typeof value === "object" ? JSON.stringify(value) : String(value);
  // Spreadsheet apps run cells that start with these characters as formulas.
  const safe = /^[=+\-@\t\r]/.test(text) ? `'${text}` : text;
  return /[",\n\r]/.test(safe) ? `"${safe.replaceAll('"', '""')}"` : safe;
}

function toCsv(rows: Record<string, unknown>[]): string {
  if (rows.length === 0) return "";
  const headers = Object.keys(rows[0]);
  const lines = [headers.join(",")];
  for (const row of rows) lines.push(headers.map((key) => csvCell(row[key])).join(","));
  return `${lines.join("\r\n")}\r\n`;
}

function back(request: NextRequest, message: string) {
  const url = new URL("/exports", request.url);
  url.searchParams.set("admin_error", message);
  return NextResponse.redirect(url, 303);
}

export async function POST(request: NextRequest) {
  // Same-origin form posts only.
  const origin = request.headers.get("origin");
  if (origin && origin !== new URL(request.url).origin) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }
  const form = await request.formData();
  const type = String(form.get("type") ?? "");
  const purpose = String(form.get("purpose") ?? "").trim();
  if (!types.has(type)) return back(request, "Choose a supported export.");
  if (purpose.length < 12) return back(request, "Describe the purpose in at least 12 characters.");

  const supabase = await createClient();
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return NextResponse.redirect(new URL("/login", request.url), 303);

  // The database enforces super admin, two-factor sign-in and records the export.
  const { data, error } = await supabase.rpc("admin_export_rows", {
    p_export_type: type,
    p_purpose: purpose,
  });
  if (error) {
    return back(request, error.code === "42501" || error.message.includes("authorization")
      ? "Only a super admin with two-factor sign-in can export."
      : "The export could not be created. Try again.");
  }
  const stamp = new Date().toISOString().slice(0, 10);
  return new NextResponse(toCsv((data ?? []) as Record<string, unknown>[]), {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="silarah-${type}-${stamp}.csv"`,
      "Cache-Control": "private, no-store, max-age=0",
    },
  });
}
