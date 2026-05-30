import { describe, it, expect } from "vitest";
import { sendLicenseEmail } from "../../src/lib/email";

describe("lib/email", () => {
  it("posts to Resend with correct shape", async () => {
    const calls: Array<{ url: string; init: RequestInit }> = [];
    const fetchImpl = async (url: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: String(url), init: init! });
      return new Response(JSON.stringify({ id: "msg_xxx" }), { status: 200 });
    };
    await sendLicenseEmail({
      apiKey: "re_test",
      to: "buyer@example.com",
      licenseKey: "DT1-abc.def.ghi",
      fetchImpl,
    });
    expect(calls).toHaveLength(1);
    expect(calls[0]!.url).toBe("https://api.resend.com/emails");
    const init = calls[0]!.init;
    const headers = init.headers as Record<string, string>;
    expect(headers["Authorization"]).toBe("Bearer re_test");
    expect(headers["Content-Type"]).toBe("application/json");
    const body = JSON.parse(init.body as string);
    expect(body.from).toMatch(/devtray\.app/);
    expect(body.to).toEqual(["buyer@example.com"]);
    expect(body.subject).toMatch(/license/i);
    expect(body.text).toContain("DT1-abc.def.ghi");
    expect(body.text).toContain("devtray://activate?license=DT1-abc.def.ghi");
  });

  it("throws on non-2xx Resend response", async () => {
    const fetchImpl = async () => new Response("oops", { status: 500 });
    await expect(
      sendLicenseEmail({
        apiKey: "re_test",
        to: "x@example.com",
        licenseKey: "DT1-x",
        fetchImpl,
      })
    ).rejects.toThrow(/resend/i);
  });
});
