import { X } from "lucide-react";
import type { GraphSession } from "@/api/graphs";
import { usePanelT } from "@/i18n/panels/hook";
import { classes } from "../style";
import { formatDate } from "./logic";

const formatValue = (value: unknown) =>
  value == null || `${value}`.trim() === "" ? "-" : String(value);

export default function SplitPanel({ host, onClose }: { host: GraphSession | null; onClose: () => void }) {
  const t = usePanelT("workspace");
  let implant: Record<string, unknown> | null = null;
  try {
    if (host?.implant_config) implant = JSON.parse(host.implant_config);
  } catch {}

  const fields = [
    [t("workspace.lastCheck"), host?.last_activity || "-"],
    [t("workspace.tag"), host?.tag],
    [t("workspace.hostname"), host?.hostname],
    [t("workspace.user"), host?.user],
    [t("workspace.privilege"), host?.privilege || "user"],
    [t("workspace.internal"), host?.internal ?? host?.ip],
    [t("workspace.external"), host?.external_ip],
    [t("workspace.listener"), host?.listener],
    [t("workspace.hostServer"), host?.host_server],
    [t("workspace.hostPort"), host?.host_port],
    [t("workspace.arch"), host?.arch],
    [t("workspace.pid"), host?.pid],
    [t("workspace.process"), host?.process],
    [t("workspace.os"), host?.os],
    [t("workspace.firstSeen"), formatDate(host?.first_seen)],
    [t("workspace.lastSeen"), formatDate(host?.last_seen)],
    [t("workspace.delay"), host?.delay],
    [t("workspace.serverLabel"), host?._server],
  ] as const;

  return (
    <>
      <div className={classes.splitHeader}>
        <span className={classes.splitTitle}>{t("workspace.viewTitle")}{host?.tag ?? t("workspace.host")}</span>
        <button type="button" onClick={onClose} className={classes.splitClose}>
          <X size={13} />
        </button>
      </div>
      <div className={classes.splitBody}>
        <div className={classes.splitContent}>
          {fields.map(([label, value]) => (
            <div key={label} className={classes.splitField}>
              <label className={classes.splitLabel}>{label}</label>
              <input
                type="text"
                readOnly
                tabIndex={-1}
                value={formatValue(value)}
                className={`${classes.splitValue} outline-none cursor-text${label === t("workspace.listener") ? " uppercase" : ""}`}
              />
            </div>
          ))}
          <div className={classes.splitField}>
            <label className={classes.splitLabel}>{t("workspace.implantConfig")}</label>
            {implant && typeof implant === "object" ? (
              <div className={classes.splitImplantBox}>
                {Object.entries(implant).map(([key, val], i, arr) => (
                  <div key={key} className={classes.splitImplantRow(i === arr.length - 1)}>
                    <span className={classes.splitImplantKey}>{key}</span>
                    <input
                      type="text"
                      readOnly
                      tabIndex={-1}
                      value={String(val)}
                      className={`${classes.splitValue} ${classes.splitImplantVal} min-w-0 flex-1 border-0 bg-transparent px-0 py-0 outline-none cursor-text`}
                    />
                  </div>
                ))}
              </div>
            ) : (
              <input
                type="text"
                readOnly
                tabIndex={-1}
                value={host?.implant_config?.trim() ? host.implant_config : "-"}
                className={`${classes.splitValue} outline-none cursor-text`}
              />
            )}
          </div>
        </div>
      </div>
    </>
  );
}
