const state = {
  devices: [],
  packages: [],
  alerts: [],
  selectedDevice: null,
};

const safeCommands = [
  { label: "Ping", command: "ping" },
  { label: "Reboot", command: "reboot" },
  { label: "Install Package", command: "install", payloadKey: "package" },
  { label: "Upgrade Package", command: "upgrade", payloadKey: "package" },
  { label: "Start App", command: "start_app", payloadKey: "app" },
  { label: "Stop App", command: "stop_app", payloadKey: "app" },
  { label: "Restart App", command: "restart_app", payloadKey: "app" },
];

function fmtTime(seconds) {
  if (!seconds) return "never";
  return new Date(seconds * 1000).toLocaleString();
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}`);
  }
  return response.json();
}

function renderStats() {
  const online = state.devices.filter((device) => device.online).length;
  const offline = state.devices.length - online;
  document.getElementById("stats").innerHTML = `
    <div class="stat"><strong>${state.devices.length}</strong><span>Total devices</span></div>
    <div class="stat"><strong>${online}</strong><span>Online</span></div>
    <div class="stat"><strong>${offline}</strong><span>Offline</span></div>
    <div class="stat"><strong>${state.alerts.length}</strong><span>Open alerts</span></div>
  `;
}

function renderDevices() {
  document.getElementById("deviceRows").innerHTML = state.devices
    .map((device) => `
      <tr>
        <td>${device.computer_id}</td>
        <td class="${device.online ? "status-online" : "status-offline"}">${device.online ? "online" : "offline"}</td>
        <td>${device.label || ""}</td>
        <td>${device.device_type}</td>
        <td>${device.agent_version}</td>
        <td>${fmtTime(device.last_seen)}</td>
      </tr>
    `)
    .join("");

  document.getElementById("deviceList").innerHTML = state.devices
    .map((device) => `<button data-device="${device.computer_id}">${device.computer_id} ${device.label || ""}</button>`)
    .join("");
  document.querySelectorAll("[data-device]").forEach((button) => {
    button.addEventListener("click", () => selectDevice(Number(button.dataset.device)));
  });

  document.getElementById("logDeviceControls").innerHTML = state.devices
    .map((device) => `<button data-log-device="${device.computer_id}">Logs ${device.computer_id}</button>`)
    .join("");
  document.querySelectorAll("[data-log-device]").forEach((button) => {
    button.addEventListener("click", () => loadLogs(Number(button.dataset.logDevice)));
  });
}

function renderPackages() {
  document.getElementById("packageList").innerHTML = state.packages.length
    ? state.packages
      .map((pkg) => `
        <div class="card">
          <h2>${pkg.name}</h2>
          <p>${pkg.description || ""}</p>
          <span>${pkg.version}</span>
        </div>
      `)
      .join("")
    : `<p class="muted">No packages registered.</p>`;
}

function renderAlerts() {
  document.getElementById("alertList").innerHTML = state.alerts.length
    ? state.alerts
      .map((alert) => `
        <div class="card">
          <h2>${alert.level}</h2>
          <p>${alert.message}</p>
          <span>${fmtTime(alert.created_at)}</span>
          <p><button data-alert="${alert.id}">Resolve</button></p>
        </div>
      `)
      .join("")
    : `<p class="muted">No open alerts.</p>`;
  document.querySelectorAll("[data-alert]").forEach((button) => {
    button.addEventListener("click", async () => {
      await api(`/api/alerts/${button.dataset.alert}/resolve`, { method: "POST", body: "{}" });
      await refresh();
    });
  });
}

async function selectDevice(computerId) {
  state.selectedDevice = computerId;
  const telemetry = await api(`/api/devices/${computerId}/telemetry?limit=1`);
  const device = state.devices.find((entry) => entry.computer_id === computerId);
  document.getElementById("detailTitle").textContent = `Device ${computerId} ${device?.label || ""}`;
  document.getElementById("telemetryBox").textContent = JSON.stringify(
    telemetry[0]?.data || device?.latest_telemetry || {},
    null,
    2,
  );
}

async function loadLogs(computerId) {
  const logs = await api(`/api/devices/${computerId}/logs?limit=200`);
  document.getElementById("logsBox").textContent = logs
    .map((entry) => `[${fmtTime(entry.ts)}] ${entry.level} ${entry.app}: ${entry.message}`)
    .join("\n") || "No logs.";
}

function renderCommandButtons() {
  document.getElementById("commandButtons").innerHTML = safeCommands
    .map((item) => `<button data-command="${item.command}" data-payload-key="${item.payloadKey || ""}">${item.label}</button>`)
    .join("");
  document.querySelectorAll("[data-command]").forEach((button) => {
    button.addEventListener("click", async () => {
      const computerId = Number(document.getElementById("commandComputerId").value);
      if (!computerId) {
        alert("Enter a computer ID.");
        return;
      }
      const payload = {};
      const key = button.dataset.payloadKey;
      if (key) {
        payload[key] = document.getElementById("commandTarget").value.trim();
      }
      await api("/api/commands", {
        method: "POST",
        body: JSON.stringify({ computer_id: computerId, command: button.dataset.command, payload }),
      });
      alert("Command queued.");
    });
  });
}

async function refresh() {
  const [devices, packagesList, alerts] = await Promise.all([
    api("/api/devices"),
    api("/api/packages"),
    api("/api/alerts"),
  ]);
  state.devices = devices;
  state.packages = packagesList;
  state.alerts = alerts;
  renderStats();
  renderDevices();
  renderPackages();
  renderAlerts();
}

document.querySelectorAll(".tabs button").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".tabs button").forEach((item) => item.classList.remove("active"));
    document.querySelectorAll(".panel").forEach((panel) => panel.classList.remove("active"));
    button.classList.add("active");
    document.getElementById(button.dataset.tab).classList.add("active");
  });
});

document.getElementById("refresh").addEventListener("click", refresh);
renderCommandButtons();
refresh().catch((error) => {
  document.getElementById("stats").innerHTML = `<div class="card">Failed to load dashboard: ${error.message}</div>`;
});

