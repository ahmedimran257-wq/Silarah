// Shared by server pages and client navigation. The database remains the
// authority (every RPC re-checks is_active_admin with its own role list);
// this matrix mirrors those lists so staff never see a screen that can only
// fail for their role.

export type AdminRole = "super_admin" | "moderator" | "support";

export type QueueCounts = Partial<Record<
  | "unreadInbox"
  | "openReports"
  | "messageReports"
  | "pendingPhotos"
  | "photoChecks"
  | "privacyOpen"
  | "privacyOverdue",
  number
>>;

const everyone: readonly AdminRole[] = ["super_admin", "moderator", "support"];
const trust: readonly AdminRole[] = ["super_admin", "moderator"];
const publishing: readonly AdminRole[] = ["super_admin", "support"];
const owner: readonly AdminRole[] = ["super_admin"];

export const areaRoles = {
  dashboard: everyone,
  inbox: everyone,
  users: everyone,
  matches: everyone,
  subscriptions: everyone,
  system: everyone,
  audit: everyone,
  photoChecks: trust,
  moderation: trust,
  memberReview: trust,
  campaigns: publishing,
  content: publishing,
  stories: publishing,
  privacy: publishing,
  deletions: publishing,
  chatFilter: trust,
  referrals: publishing,
  exports: owner,
  security: owner,
  staff: owner,
} as const satisfies Record<string, readonly AdminRole[]>;

export type Area = keyof typeof areaRoles;

export const actionRoles = {
  moderateAccounts: trust,
  banAccounts: owner,
  revealPii: trust,
  reviewPhotos: trust,
  resolveReports: trust,
  publishContent: publishing,
  manageCampaigns: publishing,
  manageStories: publishing,
  answerPrivacy: publishing,
  holdPrivacy: owner,
  manageDeletions: owner,
  recordEmailDeletion: publishing,
  removePhotos: trust,
  manageChatFilter: trust,
  messageMembers: everyone,
  writeNotes: everyone,
  endReferralGrants: owner,
  removeGuardian: trust,
  exportData: owner,
  grantTestPremium: owner,
  manageStaff: owner,
} as const satisfies Record<string, readonly AdminRole[]>;

export type AdminAction = keyof typeof actionRoles;

export function canAccess(role: AdminRole, area: Area) {
  return (areaRoles[area] as readonly AdminRole[]).includes(role);
}

export function can(role: AdminRole, action: AdminAction) {
  return (actionRoles[action] as readonly AdminRole[]).includes(role);
}

export const roleLabels: Record<AdminRole, string> = {
  super_admin: "Super admin",
  moderator: "Moderator",
  support: "Support",
};

export type NavItem = {
  href: string;
  label: string;
  area: Area;
  icon: string;
  count?: (counts: QueueCounts) => number;
  urgent?: (counts: QueueCounts) => boolean;
};

export const navGroups: { label: string; items: NavItem[] }[] = [
  {
    label: "Today",
    items: [
      { href: "/dashboard", label: "Overview", area: "dashboard", icon: "overview" },
      { href: "/inbox", label: "Inbox", area: "inbox", icon: "inbox", count: (c) => c.unreadInbox ?? 0 },
    ],
  },
  {
    label: "Trust & safety",
    items: [
      { href: "/photo-verification", label: "Photo checks", area: "photoChecks", icon: "photoCheck", count: (c) => c.photoChecks ?? 0, urgent: (c) => (c.photoChecks ?? 0) > 0 },
      {
        href: "/moderation", label: "Moderation", area: "moderation", icon: "moderation",
        count: (c) => (c.openReports ?? 0) + (c.messageReports ?? 0) + (c.pendingPhotos ?? 0),
        urgent: (c) => (c.openReports ?? 0) + (c.messageReports ?? 0) > 0,
      },
      { href: "/privacy", label: "Member rights", area: "privacy", icon: "privacy", count: (c) => c.privacyOpen ?? 0, urgent: (c) => (c.privacyOverdue ?? 0) > 0 },
      { href: "/deletions", label: "Deletions", area: "deletions", icon: "deletions" },
      { href: "/chat-filter", label: "Chat filter", area: "chatFilter", icon: "chatFilter" },
    ],
  },
  {
    label: "Members",
    items: [
      { href: "/users", label: "Members", area: "users", icon: "members" },
      { href: "/matches", label: "Matches", area: "matches", icon: "matches" },
      { href: "/subscriptions", label: "Subscriptions", area: "subscriptions", icon: "subscriptions" },
      { href: "/referrals", label: "Referrals", area: "referrals", icon: "referrals" },
    ],
  },
  {
    label: "Publishing",
    items: [
      { href: "/campaigns", label: "Campaigns", area: "campaigns", icon: "campaigns" },
      { href: "/content", label: "Content", area: "content", icon: "content" },
      { href: "/stories", label: "Stories", area: "stories", icon: "stories" },
    ],
  },
  {
    label: "Governance",
    items: [
      { href: "/audit", label: "Audit trail", area: "audit", icon: "audit" },
      { href: "/security", label: "Security", area: "security", icon: "security" },
      { href: "/staff", label: "Staff access", area: "staff", icon: "staff" },
      { href: "/system", label: "System health", area: "system", icon: "system" },
      { href: "/exports", label: "Exports", area: "exports", icon: "exports" },
    ],
  },
];

export function pageTitle(pathname: string) {
  for (const group of navGroups) {
    for (const item of group.items) {
      if (pathname === item.href || pathname.startsWith(`${item.href}/`)) return item.label;
    }
  }
  return "Operations";
}

export function formatCount(value: number) {
  return value >= 1000 ? "999+" : value.toLocaleString("en-IN");
}
