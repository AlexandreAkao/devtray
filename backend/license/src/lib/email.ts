type FetchImpl = typeof fetch;

export type SendLicenseEmailArgs = {
  apiKey: string;
  to: string;
  licenseKey: string;
  fetchImpl?: FetchImpl;
  from?: string;
};

export async function sendLicenseEmail(args: SendLicenseEmailArgs): Promise<void> {
  const f = args.fetchImpl ?? fetch;
  const from = args.from ?? "DevTray <licenses@devtray.app>";
  const deepLink = `devtray://activate?license=${encodeURIComponent(args.licenseKey)}`;

  const body = {
    from,
    to: [args.to],
    subject: "Your DevTray license",
    text: [
      "Thanks for buying DevTray!",
      "",
      "Click to activate (opens DevTray):",
      deepLink,
      "",
      "Or paste this license key in Settings → License:",
      args.licenseKey,
      "",
      "Need to deactivate a Mac you no longer have? Reply to this email.",
    ].join("\n"),
  };

  const res = await f("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${args.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    throw new Error(`resend send failed: ${res.status}`);
  }
}
