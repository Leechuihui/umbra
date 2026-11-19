import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  Bug,
  Headphones,
  MonitorIcon,
  RefreshCw,
  Server,
  ShieldAlert,
  TrendingUp,
} from "lucide-react";
import { usePanelT } from "@/i18n/panels/hook";
import { fetchSessions, type Session } from "@/api/sessions";
import { fetchListeners } from "@/api/listeners";

/**
 * UMBRA original overview dashboard.
 *
 * Aggregates live session / listener telemetry into a single at-a-glance
 * command surface. Fully client-side; no extra server endpoint required.
 */

type StatCard = {
  key: string;
  label: string;
  value: number | string;
  hint?: string;
  icon: React.ReactNode;
  accent?: boolean;
};

function osBreakdown(sessions: Session[]) {
  const counts = new Map<string, number>();
  for (const s of sessions) {
    const os = (s.os || "unknown").toLowerCase();
    counts.set(os, (counts.get(os) ?? 0) + 1);
  }
  return [...counts.entries()].sort((a, b) => b[1] - a[1]);
}

function privilegeBreakdown(sessions: Session[]) {
  let elevated = 0;
  for (const s of sessions) {
    const p = (s.privilege ?? "").toLowerCase();
    if (p.includes("system") || p.includes("admin") || p.includes("root")) elevated += 1;
  }
  return elevated;
}

export default function DashboardPanel() {
  const t = usePanelT("dashboard");
  const [sessions, setSessions] = useState<Session[]>([]);
  const [listeners, setListeners] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [lastSync, setLastSync] = useState<string>("");

  const load = async () => {
    setLoading(true);
    const [sessRes, lisRes] = await Promise.all([
      fetchSessions("default").catch(() => null),
      fetchListeners().catch(() => []),
    ]);
    if (sessRes?.status === "success" && Array.isArray(sessRes.sessions)) {
      setSessions(sessRes.sessions as Session[]);
    } else {
      setSessions([]);
    }
    setListeners(Array.isArray(lisRes) ? lisRes : []);
    setLastSync(new Date().toLocaleTimeString());
    setLoading(false);
  };

  useEffect(() => {
    void load();
  }, []);

  const serverCount = useMemo(
    () => new Set(sessions.map((s) => s._server).filter(Boolean)).size,
    [sessions],
  );
  const elevated = useMemo(() => privilegeBreakdown(sessions), [sessions]);
  const osRows = useMemo(() => osBreakdown(sessions), [sessions]);

  const cards: StatCard[] = [
    {
      key: "sessions",
      label: t("dashboard.activeSessions"),
      value: sessions.length,
      icon: <MonitorIcon size={15} />,
      accent: true,
    },
    {
      key: "listeners",
      label: t("dashboard.activeListeners"),
      value: listeners.length,
      icon: <Headphones size={15} />,
    },
    {
      key: "servers",
      label: t("dashboard.teamServers"),
      value: serverCount,
      icon: <Server size={15} />,
    },
    {
      key: "elevated",
      label: t("dashboard.elevated"),
      value: elevated,
      hint: sessions.length ? `${Math.round((elevated / sessions.length) * 100)}%` : undefined,
      icon: <ShieldAlert size={15} />,
    },
  ];

  return (
    <div className="flex flex-col h-full bg-[#171717] text-[#d4d4d4] text-[12px] select-none overflow-hidden">
      <div className="flex items-center justify-between px-4 py-2.5 border-b border-[#252525] shrink-0">
        <span className="flex items-center gap-2 text-[13.5px] font-semibold text-[#cecece]">
          <Activity size={14} className="umbra-accent-text" />
          {t("dashboard.title")}
        </span>
        <div className="flex items-center gap-2">
          {lastSync && (
            <span className="text-[11px] text-[#555] tabular-nums">
              {t("dashboard.syncedAt")} {lastSync}
            </span>
          )}
          <button
            type="button"
            onClick={() => void load()}
            disabled={loading}
            className="button-default flex h-[26px] items-center gap-1.5 rounded border border-[#333] bg-[#232323] px-2.5 text-[12px] text-[#cecece] hover:bg-[#2b2b2b] cursor-pointer disabled:opacity-40"
          >
            <RefreshCw size={11} className={loading ? "animate-spin" : ""} />
            {t("dashboard.refresh")}
          </button>
        </div>
      </div>

      <div className="flex-1 min-h-0 overflow-y-auto p-3 space-y-3">
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-2.5">
          {cards.map((card) => (
            <div key={card.key} className="umbra-card px-3 py-2.5">
              <div className="flex items-center gap-1.5 text-[11px] uppercase tracking-widest text-[#6e6e6e]">
                <span className={card.accent ? "umbra-accent-text" : ""}>{card.icon}</span>
                {card.label}
              </div>
              <div className="mt-1.5 flex items-baseline gap-2">
                <span className={`umbra-stat-value text-[24px] font-semibold ${card.accent ? "umbra-accent-text" : "text-[#e0e0e0]"}`}>
                  {card.value}
                </span>
                {card.hint && <span className="text-[11px] text-[#666]">{card.hint}</span>}
              </div>
            </div>
          ))}
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-2.5">
          <div className="umbra-card p-3">
            <div className="flex items-center gap-1.5 mb-2.5 text-[11px] uppercase tracking-widest text-[#6e6e6e]">
              <TrendingUp size={13} />
              {t("dashboard.osDistribution")}
            </div>
            {osRows.length === 0 ? (
              <div className="py-6 text-center text-[12px] text-[#555]">{t("dashboard.noData")}</div>
            ) : (
              <div className="space-y-1.5">
                {osRows.map(([os, count]) => {
                  const pct = sessions.length ? Math.round((count / sessions.length) * 100) : 0;
                  return (
                    <div key={os} className="flex items-center gap-2">
                      <span className="w-[5.5rem] shrink-0 truncate text-[12px] text-[#a0a0a0] capitalize">{os}</span>
                      <div className="flex-1 h-[6px] rounded-full bg-[#242424] overflow-hidden">
                        <div
                          className="h-full rounded-full umbra-accent-bg"
                          style={{ width: `${pct}%`, opacity: 0.85 }}
                        />
                      </div>
                      <span className="w-9 shrink-0 text-right tabular-nums text-[11px] text-[#777]">{count}</span>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          <div className="umbra-card p-3">
            <div className="flex items-center gap-1.5 mb-2.5 text-[11px] uppercase tracking-widest text-[#6e6e6e]">
              <Bug size={13} />
              {t("dashboard.recentSessions")}
            </div>
            {sessions.length === 0 ? (
              <div className="py-6 text-center text-[12px] text-[#555]">{t("dashboard.noData")}</div>
            ) : (
              <div className="space-y-1">
                {sessions.slice(0, 6).map((s) => (
                  <div
                    key={`${s._server}-${s.tag}`}
                    className="flex items-center justify-between gap-2 rounded px-1.5 py-1 hover:bg-[#1e1e1e]"
                  >
                    <span className="flex items-center gap-2 min-w-0">
                      <span className="size-1.5 rounded-full umbra-accent-bg shrink-0" />
                      <span className="truncate text-[12px] text-[#cecece]">{s.tag || s.ip}</span>
                    </span>
                    <span className="shrink-0 text-[11px] text-[#666] capitalize">
                      {s.os} · {s.user || "-"}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
